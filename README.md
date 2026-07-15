# Posts App — Local Run Guide

## What this is
6 containers, wired together:

```
frontend (React, port 3000)
   |
   v
api (Node/Express, port 4000)
   |--- write path --> rabbitmq (queue) --> worker --> postgres
   |--- read path  --> redis (cache) --> postgres (on cache miss)
```

- **frontend**: React app, served by Nginx after build. Has a form to create a
  post and a search box to filter posts.
- **api**: the only thing the frontend talks to. Reads go through Redis
  (cache-first). Writes are NOT written to Postgres directly — they're
  published to a RabbitMQ queue instead.
- **worker**: separate process that consumes messages off the queue, writes
  them to Postgres, and invalidates the Redis cache so the next read is
  fresh.
- **postgres**: the database. Schema is created automatically from
  `db/init.sql` on first startup.
- **redis**: cache only, in front of Postgres reads.
- **rabbitmq**: the queue between api (producer) and worker (consumer). It
  also ships a web UI at http://localhost:15672 (login: guest/guest) where
  you can literally watch messages flow through the queue — useful for
  understanding what's happening.

## Prerequisites
- Docker + Docker Compose installed. That's it — you don't need Node,
  Postgres, Redis, or RabbitMQ installed locally; everything runs in
  containers.

## Run it

```bash
cd project
docker compose up --build
```

First run will take a minute or two (building images, pulling base images).
Once it settles, you'll see logs from all 6 containers interleaved.

Open:
- **App**: http://localhost:3000
- **RabbitMQ management UI**: http://localhost:15672 (guest/guest) — go to
  the "Queues" tab and click `posts_queue` to watch messages arrive and
  get consumed in real time.

## Try it out
1. Open http://localhost:3000
2. Fill in the "New Post" form and submit. You'll immediately see
   "Queued!" — note the post does NOT appear instantly, because it's sitting
   in the queue waiting for the worker to process it. After ~1-2 seconds it
   will show up (the UI auto-refreshes once).
3. Watch the terminal logs — you'll see the `api` container log the queue
   publish, then the `worker` container log that it saved the post.
4. Use the search box to filter posts by title/content (hits Postgres
   directly — search results aren't cached).
5. Refresh the list a couple of times — the first request after a write is
   a cache miss (source: "db" if you inspect the network tab), subsequent
   ones within 30 seconds are cache hits (source: "cache").

## Stopping / resetting

```bash
# stop containers, keep data
docker compose down

# stop containers AND wipe the postgres volume (fresh DB next time)
docker compose down -v
```

## Rebuilding after code changes
```bash
docker compose up --build
```
(`--build` forces Docker to rebuild images instead of using cached layers.)

## Checking individual pieces
```bash
# see logs for just one service
docker compose logs -f api
docker compose logs -f worker

# check postgres directly
docker exec -it postgres psql -U postgres -d postsdb -c "SELECT * FROM posts;"

# check redis directly
docker exec -it redis redis-cli GET posts:all

# check container health/status
docker compose ps
```

## Notes for later phases
- **Postgres → RDS**: swap `PGHOST` env var to the RDS endpoint, remove the
  postgres service from compose. No app code changes needed.
- **Redis → ElastiCache**: same idea, swap `REDIS_HOST`.
- **RabbitMQ → SQS or managed broker**: would need a small change in
  `api/index.js` and `worker/index.js` (different client library), but the
  architecture (producer/consumer decoupling) stays identical.
- **k8s later**: each service here becomes a Deployment + Service. The
  container-to-container hostnames (`postgres`, `redis`, `rabbitmq`, `api`)
  you're using now are exactly the pattern k8s DNS-based service discovery
  uses (`servicename.namespace.svc.cluster.local`), so this compose setup is
  intentionally practicing that habit already.
