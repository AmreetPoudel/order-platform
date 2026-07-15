# Order Platform — Phase 1 Architecture (Local Docker Compose)

## Scope of this phase

Everything in this document describes the current state: the entire stack
running on a single machine via `docker compose up`, using hardcoded
environment variables in the compose file. This is the foundation phase —
before any CI/CD, before Terraform, before a real server. The goal here is
a correct mental model of how six containers become one working
application on one machine, so that later phases (SSH-based deploy to a
manual server, then Terraform-provisioned servers, then EKS + ArgoCD) are
extending a system that's already well understood, not a black box that
happened to work.

Environment variables are hardcoded directly in `docker-compose.yml` for
this phase. Later phases will fetch these dynamically from AWS (Secrets
Manager / SSM Parameter Store) instead — that change is deliberately out
of scope here and is called out in the "what changes later" section at the
end.

## The six services

| Service    | Has its own Dockerfile? | Source |
|------------|--------------------------|--------|
| `frontend` | Yes — multi-stage: `node:20-alpine` build stage, `nginx:alpine` serve stage | Built from `./frontend` |
| `api`      | Yes | Built from `./backend` |
| `worker`   | Yes | Built from `./worker` |
| `postgres` | No — stock image | `postgres:16-alpine` from Docker Hub |
| `redis`    | No — stock image | `redis:7-alpine` from Docker Hub |
| `rabbitmq` | No — stock image | `rabbitmq:3-management-alpine` from Docker Hub |

`api` and `worker` are two separate services built from the same
conceptual backend codebase but running as two different processes with
two different responsibilities — this split is the core of the whole
architecture and is explained in the flow sections below.

## What the compose file actually does

`docker-compose.yml` is the single orchestration point for this phase. It
does three jobs, and it's worth being precise that these are three
separate jobs, not one blurred concern:

1. **Build instructions** — for `frontend`, `api`, and `worker`, it points
   at each service's Dockerfile (`build: ./backend`, etc.) and tells
   Compose to build an image from source rather than pull one.
2. **Environment variable injection** — each service's `environment:`
   block hardcodes its config (`PGHOST: postgres`, `REDIS_HOST: redis`,
   `RABBITMQ_HOST: rabbitmq`, credentials, etc.) directly into that
   container's process environment at container start. The application
   code (Node's `process.env`) reads these values — Compose doesn't
   interpret or validate them, it just sets them.
3. **Networking** — Compose creates a custom bridge network and attaches
   every service to it, which is what makes name-based resolution between
   containers possible at all (see next section).

Compose itself has no involvement in cache logic, queue logic, or the
read/write patterns described below — all of that is implemented in
`api/index.js` and `worker/index.js`. Compose's job ends at "build these
images, give them these env vars, put them on the same network." What the
application does with that is entirely code, not orchestration.

## How containers find each other: DNS resolution

Because all six services sit on the same Compose-created network, Docker
runs an embedded DNS resolver inside every container at the fixed address
`127.0.0.11`. Each container's `/etc/resolv.conf` is automatically pointed
at that address. When `api`'s code resolves the hostname `postgres`
(because `PGHOST=postgres`), the sequence is:

1. Node's DNS lookup queries `127.0.0.11`.
2. Docker's embedded resolver checks its live table of service names →
   current internal IPs on that network.
3. It returns the current IP of the `postgres` container (something like
   `172.20.0.3`).
4. Node connects to that IP on port 5432.

The name being resolved is the **Compose service name** (the YAML key,
e.g. `postgres`), not necessarily `container_name`. In this project's
compose file, `container_name` happens to be set to the same string as
the service name for convenience (so `docker exec -it postgres ...` reads
cleanly), but that's cosmetic — DNS resolution would work identically
without `container_name` being set at all, because Compose auto-registers
the service name regardless.

This resolution survives container restarts: if `postgres` restarts and
gets a new internal IP, the DNS entry for the name `postgres` updates
automatically. The application never hardcodes an IP, only ever the
service name, which is what makes `PGHOST=postgres` a stable value across
the container's entire lifecycle.

**What DNS resolution does NOT guarantee:** that a name resolves to an IP
only means the container exists on the network — it says nothing about
whether the process inside that container is actually ready to accept
connections yet. Postgres/Redis/RabbitMQ can all be resolvable via DNS
seconds before they're actually listening and accepting queries. This is
why `api` and `worker` have (or, in Redis's case, should have but
currently don't) retry loops around their connection attempts on startup
— DNS being resolvable and a service being ready are two different
conditions.

## A related but distinct mechanism: reaching the host machine itself

Some real-world compose files (not this one, but worth documenting since
it's a natural next question) include:

```yaml
extra_hosts:
  - host.docker.internal:host-gateway
```

This is unrelated to container-to-container DNS above. It solves a
different problem: letting a container reach a process running natively
on the host machine itself — not inside any container. Docker adds a
manual entry so `host.docker.internal` resolves to the host's gateway IP
from inside the container. This matters when, for example, a
containerized app needs to talk to a database installed directly on the
host OS rather than running as a container, or during local development
when a container needs to reach a tool running on the developer's own
machine outside Docker entirely.

For completeness, the three distinct addressing cases in this kind of
setup:

| Target | Mechanism |
|---|---|
| Another container, same Docker network | Service name via Docker's embedded DNS (`127.0.0.11`) |
| Another container, different Docker network | Attach to both networks, or route through a published host port |
| The host machine itself (non-containerized process) | `host.docker.internal`, enabled via `extra_hosts: host-gateway` |

## Config in files vs config as environment variables

Also worth documenting here since it's a pattern you'll see in real prod
compose files even though this project's own compose file doesn't use it:
some setups bind-mount a `.env` file into the container instead of (or in
addition to) using the `environment:` block —

```yaml
volumes:
  - ./.env:/app/.env:ro
```

This is a bind mount, not environment injection — Compose does not read
or parse that file itself; it only makes the host's `.env` file visible
inside the container at that path. It's the **application code** (via a
library like `dotenv`) that opens the file and populates `process.env` at
startup. Compose and Docker have no awareness this parsing happened. The
practical reason a real deployment favors this over hardcoding values in
`environment:` is that it keeps actual secrets out of `docker-compose.yml`
(which is usually committed to Git) and instead confined to a file that
stays on the server's disk and is `.gitignore`'d — different `.env`
contents per environment (developer's machine vs actual server), same
mechanism.

## Write flow (POST) and read flow (GET) — two independent flows

These are commonly conflated, so it's worth stating plainly: a POST
request and a GET request run through two entirely separate code paths
that only share one point of contact — a single Redis key, `posts:all`.

### Write flow

1. Browser sends `POST /api/posts`.
2. `api` publishes the message to RabbitMQ. `api` does not touch Postgres
   or Redis on write at all.
3. `api` returns `202 Queued` immediately — this response says nothing
   about whether the write has actually landed in Postgres yet.
4. `worker`, a fully separate process consuming from RabbitMQ
   independently of any browser request, picks the message up.
5. `worker` runs `INSERT INTO posts` — the row is now permanently in
   Postgres.
6. `worker` runs `DEL posts:all` on Redis — unconditionally, with no
   check of whether it was a hit or miss. It never reads Redis at all.
7. `worker` acks the message.

### Read flow

1. Browser sends `GET /api/posts`.
2. `api` (not `worker` — this decision is made exclusively in the API's
   GET handler) checks Redis for `posts:all`.
3. Cache hit → return cached data, Postgres untouched.
4. Cache miss → query Postgres, write the fresh result into Redis with a
   30 second TTL, return it.

### Why "next read after a write is a miss" is not a hard guarantee

INSERT happens before DEL (not the reverse) specifically to avoid a worse
bug: if DEL ran first, there'd be a window where the cache is empty but
the row isn't in Postgres yet, and a read landing in that window would
re-cache stale data for a full TTL cycle. INSERT-then-DEL avoids that.

But even with this ordering, there's a genuine race: a GET request that
started *before* the worker's INSERT commits can finish its own Postgres
query (returning old data) *after* the worker's DEL has already run, and
then write that stale result back into Redis — silently undoing the
invalidation. The system's actual guarantee is eventual consistency
bounded by the 30 second TTL, not instant freshness on the very next read.
Fixing this properly would require a distributed lock, a versioned cache
key, or a write-through cache where the worker writes the fresh value
directly instead of only deleting — none of which is implemented
currently.

## Known gaps in this phase (carried forward, not silently patched)

- No dead-letter queue: `worker` does `nack(msg, false, false)` on error,
  which silently drops the message with no retry and no record of the
  failure.
- No idempotency key on writes: a double-submit creates duplicate rows.
- No retry loop around the Redis connection in `worker`/`api` startup
  (unlike RabbitMQ, which does retry) — a race if Redis is slow to accept
  connections.
- `prefetch(1)` gives ordering only within a single worker instance;
  scaling worker replicas loses any ordering guarantee across the whole
  queue.
- Search (`/api/posts/search`) is an unindexed `ILIKE` scan — fine at
  small scale, won't hold up on real data volume without `pg_trgm` + GIN
  or a dedicated search engine.
- Environment variables and secrets are hardcoded in `docker-compose.yml`
  for this phase — acceptable for local dev, not carried forward as-is.

## Running it

```bash
cd order-platform
docker compose up --build
```

- App: http://localhost:3000
- API health: http://localhost:4000/health
- RabbitMQ management UI: http://localhost:15672 (guest/guest)

## What changes in later phases

This document describes Phase 1 only: one machine, one `docker compose
up`, hardcoded config. Nothing about the application code, the read/write
flows, or the cache/queue behavior changes in later phases — only how the
containers get built, deployed, and configured changes:

- **Phase 1 (deploy)**: images built and pushed to Docker Hub, deployed to
  a manually provisioned server via SSH-based CI/CD. Same compose file
  concept, now running on a remote box instead of your own machine.
- **Phase 2**: the server itself becomes Terraform-managed instead of
  manually created. Deployment mechanism is unchanged — still SSH-based.
- **Phase 3**: no SSH at all. Deployment moves to EKS, reconciled by
  ArgoCD from Git as the source of truth. This is also where the
  hardcoded environment variables in this document get replaced by
  dynamic secrets pulled from AWS Secrets Manager or SSM Parameter Store,
  and where the Redis-connection retry gap and the DNS-resolves-but-not-
  ready gap both get fixed properly via Kubernetes readiness probes
  instead of ad-hoc retry loops.