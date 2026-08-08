# Order Platform — Architecture & Operations Guide

A 6-container distributed application demonstrating **cache-aside reads**, **producer/consumer queue-based async writes**, **Terraform Infrastructure-as-Code**, **dynamic AWS SSM secrets management**, and an **automated CI/CD deployment pipeline with health checks and rollbacks**.

---

## 1. Project Phase Status

| Phase | Infrastructure & Architecture | Status |
|---|---|---|
| **Phase 1** | Local Docker Compose multi-container stack (`api`, `worker`, `frontend`, `postgres`, `redis`, `rabbitmq`) | ✅ Complete |
| **Phase 2** | AWS Terraform IaC (`vpc`, `ec2`, `security_group`, `iam`, `oidc`), Dynamic SSM Secrets, GitHub Actions CI/CD, Health Checks, S3 Versioning & Automated Rollback | ✅ Complete |
| **Phase 3** | Kubernetes Migration (AWS EKS), ArgoCD GitOps, Helm Charts, External Secrets Operator, Managed RDS & ElastiCache | ⏳ Planned |

---

## 2. System Architecture

```
                  ┌───────────────┐
                  │ Browser (SPA) │
                  └───────┬───────┘
                          │ (React / Nginx)
                          ▼
                  ┌───────────────┐
            ┌────►│   API (Node)  ├───────────┐
            │     └───────┬───────┘           │
   GET      │             │ POST              │ GET (Cache Miss)
(Cache Hit) │             │ (202 Queued)      │
            ▼             ▼                   ▼
      ┌───────────┐ ┌───────────┐       ┌───────────┐
      │   Redis   │ │ RabbitMQ  │       │ Postgres  │
      └─────▲─────┘ └─────┬─────┘       └─────▲─────┘
            │             │                   │
            │ Cache DEL   │ Consume           │ INSERT
            └─────────────┴─────► Worker ─────┘
                                  (Node)
```

### Component Summary

| Service | Stack | Role | Access / Port |
|---|---|---|---|
| `frontend` | React SPA + Nginx | Serves static UI build | Public `:3000` |
| `api` | Node.js + Express | Validates HTTP requests, reads from Redis/DB, pushes writes to queue | Public `:4000` |
| `worker` | Node.js (Async Consumer) | Consumes queue (`prefetch=1`), inserts to DB, invalidates Redis cache | Internal (No open ports) |
| `postgres` | PostgreSQL 16 Alpine | Primary persistent database (`postsdb`) | Internal (5432, localhost `:5432`) |
| `redis` | Redis 7 Alpine | Cache layer for `GET /api/posts` (30s TTL) | Internal (6379, localhost `:6379`) |
| `rabbitmq` | RabbitMQ 3 Management | Asynchronous message broker (`posts_queue`) | Internal (5672), UI `:15672` (SSH tunnel) |

---

## 3. Distributed Request Flows

### Write Path (Decoupled Async Writes)
1. Browser sends `POST /api/posts {title, content}`.
2. `api` publishes persistent message to `posts_queue` in RabbitMQ.
3. `api` returns `HTTP 202 Queued` immediately.
4. `worker` picks up message, executes `INSERT INTO posts`, and runs `DEL posts:all` on Redis.
5. `worker` acknowledges message in RabbitMQ.

### Read Path (Cache-Aside Pattern)
1. Browser sends `GET /api/posts`.
2. `api` queries Redis for `posts:all`.
3. **Cache Hit**: Returns cached JSON immediately.
4. **Cache Miss**: Queries PostgreSQL, caches result in Redis with 30s TTL, returns JSON (`source: "db"`).

---

## 4. Infrastructure & Infrastructure as Code (Terraform)

Infrastructure is managed using Terraform in `infra/`:

```
infra/
├── environments/
│   └── dev/                  # Environment entrypoint (S3 Backend, Module calls)
└── modules/
    ├── vpc/                  # VPC & Subnet
    ├── internet_gateway/     # Internet Gateway
    ├── route_table/          # Route Tables & Subnet Associations
    ├── elastic_ip/           # AWS Elastic IP
    ├── security_group/       # Firewall / Ingress / Egress rules
    ├── ec2/                  # Ubuntu EC2 Instance with Docker
    ├── iam_role/             # EC2 SSM Read & S3 State IAM Roles
    └── oidc/                 # GitHub Actions AWS OIDC Provider & Roles
```

### Remote State Configuration
State is stored centrally in AWS S3 with native lockfiles (`use_lockfile = true`):

```bash
cd infra/environments/dev
terraform init
terraform plan
terraform apply
```

---

## 5. Dynamic Secrets Management

Secrets (`PG_PASSWORD`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`) are stored securely in **AWS SSM Parameter Store** under `/order-platform/*`.

On the EC2 server, `scripts/dev/fetch_secrets.sh` batch-fetches parameters using the server's IAM instance profile and exports them into the environment prior to launch:

```bash
# Source secrets into current shell session
source scripts/dev/fetch_secrets.sh

# Run stack with populated environment variables
docker compose up -d
```

---

## 6. Automated CI/CD Pipelines

### CI Pipeline (`.github/workflows/ci.yaml`)
- Runs `gitleaks` secret scanning across full repository history.
- Performs `npm audit` on backend, worker, and frontend services.
- Builds Docker images once with dual-tagging (local `:scan` and remote `${{ github.sha }}`).
- Scans images for vulnerabilities using `trivy`.
- Pushes SHA-tagged images to Docker Hub and notifies Discord.

### CD Pipeline (`.github/workflows/cd.yaml`)
- Authenticates via AWS IAM OIDC (`aws-actions/configure-aws-credentials`).
- Copies deployment configuration to EC2 via SCP.
- Sources SSM secrets via `fetch_secrets.sh`.
- Executes `docker compose pull` and `docker compose up -d`.
- Performs an automated 15-retry HTTP health check (`http://localhost:4000/health`).
- Updates S3 deployment version tracking on success (`update-version.sh`).

---

## 7. Version Tracking & Rollback Operations

### Automated Version Register (`s3://order-platform-tf-state-891274465984/deploy/dev/versions.json`)
Every successful deployment shifts version history in S3:
```json
{
  "current": "<latest-successful-git-sha>",
  "previous": "<previous-git-sha>",
  "oldest": "<oldest-git-sha>"
}
```

### Executing a Manual Rollback
If a deployment exhibits issues after passing initial health checks, execute the rollback script on the server:

```bash
ssh ubuntu@<EC2_PUBLIC_IP>
cd /home/ubuntu/order-platform
bash scripts/dev/rollback.sh
```

`rollback.sh` fetches the last known-good SHA from S3, pulls the previous container images, restarts the stack, and verifies service health.

---

## 8. Local Development & Debugging

### Running Locally with Docker Compose
```bash
docker compose up --build
```

- **Frontend SPA**: http://localhost:3000
- **API Health**: http://localhost:4000/health
- **RabbitMQ Management**: http://localhost:15672 (User: `guest` / Pass: `guest`)

### Inspection Commands
```bash
# View API & Worker logs
docker compose logs -f api worker

# Query PostgreSQL directly
docker exec -it postgres psql -U postgres -d postsdb -c "SELECT * FROM posts;"

# Inspect Redis Cache
docker exec -it redis redis-cli GET posts:all
docker exec -it redis redis-cli TTL posts:all
```
