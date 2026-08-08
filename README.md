# Order Platform — Architecture & Operations Guide (AWS ECS Fargate)

A 6-container distributed cloud application demonstrating **cache-aside reads**, **producer/consumer queue-based async writes**, **Terraform Infrastructure-as-Code**, **AWS ECS Fargate serverless container orchestration**, **AWS Cloud Map private DNS**, **EFS persistent storage**, and **automated GitHub Actions CI/CD pipelines**.

---

## 1. Project Phase Matrix

| Phase | Infrastructure & Architecture | Status |
|---|---|---|
| **Phase 1** | Local multi-container Docker Compose stack (`api`, `worker`, `frontend`, `postgres`, `redis`, `rabbitmq`) | ✅ Complete |
| **Phase 2** | AWS ECS Fargate serverless container stack, Application Load Balancer (ALB), Cloud Map Private DNS (`order-platform.local`), EFS persistence, SSM Secret injection, GitHub Actions OIDC & ECS deployments | ✅ Active (`fargate-ecs`) |
| **Phase 3** | AWS EKS (Kubernetes), ArgoCD GitOps, Helm Charts, External Secrets Operator, AWS Managed RDS & ElastiCache | ⏳ Planned |

---

## 2. High-Level System Architecture

```
                               ┌───────────────────────────┐
                               │   Public Internet Traffic │
                               └─────────────┬─────────────┘
                                             │
                                             ▼
                               ┌───────────────────────────┐
                               │ Application Load Balancer │
                               │        (Public ALB)       │
                               └─────────────┬─────────────┘
                                             │
                       ┌─────────────────────┴─────────────────────┐
             Path: /*  │                                  Path: /api/* & /health
                       ▼                                           ▼
          ┌──────────────────────────┐                ┌──────────────────────────┐
          │   Frontend Target Group  │                │     API Target Group     │
          └────────────┬─────────────┘                └────────────┬─────────────┘
                       │                                           │
                       ▼                                           ▼
          ┌──────────────────────────┐                ┌──────────────────────────┐
          │  Frontend Task (Fargate) │                │    API Task (Fargate)    │
          └──────────────────────────┘                └────────────┬─────────────┘
                                                                   │
                                                ┌──────────────────┴──────────────────┐
                                                │ (Cloud Map: order-platform.local)   │
                                                ▼                                     ▼
                                      ┌──────────────────┐                  ┌──────────────────┐
                                      │   Redis Task     │                  │  RabbitMQ Task   │
                                      │ (Cache, 30s TTL) │                  │ (Message Queue)  │
                                      └──────────────────┘                  └────────┬─────────┘
                                                                                     │ Consume
                                                                                     ▼
                                      ┌──────────────────┐                  ┌──────────────────┐
                                      │  PostgreSQL Task │◄─────────────────│   Worker Task    │
                                      │  (EFS Persistent)│     INSERT       │ (Queue Consumer) │
                                      └──────────────────┘                  └──────────────────┘
```

---

## 3. Microservice Infrastructure Summary

| Component | Container Image | Sizing (CPU / RAM) | Network / Discovery Endpoint | Persistent Storage |
|---|---|---|---|---|
| `frontend` | `${DOCKERHUB_USERNAME}/order-platform-frontend:${SHA}` | `256` / `512 MB` | ALB Listener Path `/*` (Port 80) | Ephemeral |
| `api` | `${DOCKERHUB_USERNAME}/order-platform-api:${SHA}` | `256` / `512 MB` | ALB Listener Path `/api/*` & `/health` (Port 4000) | Ephemeral |
| `worker` | `${DOCKERHUB_USERNAME}/order-platform-worker:${SHA}` | `256` / `512 MB` | Internal Queue Consumer | Ephemeral |
| `postgres` | `postgres:16-alpine` | `256` / `512 MB` | `postgres.order-platform.local:5432` | Amazon EFS (`/var/lib/postgresql/data`) |
| `redis` | `redis:7-alpine` | `256` / `512 MB` | `redis.order-platform.local:6379` | In-memory |
| `rabbitmq` | `rabbitmq:3-management-alpine` | `256` / `512 MB` | `rabbitmq.order-platform.local:5672` / `:15672` | Ephemeral |

---

## 4. Distributed Application Flow Patterns

### 1. Write Path (Decoupled Async Writes)
1. Browser sends `POST /api/posts {title, content}` to ALB.
2. ALB forwards request to `api` target group on port `4000`.
3. `api` task publishes a persistent JSON message to `posts_queue` in `rabbitmq.order-platform.local:5672`.
4. `api` task returns `HTTP 202 Queued` immediately without waiting for database persistence.
5. `worker` task continuously consumes from `posts_queue` (`prefetch=1`).
6. `worker` inserts record into `postgres.order-platform.local:5432` and invalidates Redis cache key (`DEL posts:all`).

### 2. Read Path (Cache-Aside Pattern)
1. Browser sends `GET /api/posts` to ALB.
2. ALB forwards request to `api` target group on port `4000`.
3. `api` task queries `redis.order-platform.local:6379` for key `posts:all`.
4. **Cache Hit**: Returns cached JSON string directly (`source: "cache"`).
5. **Cache Miss**: Queries `postgres.order-platform.local:5432`, caches result in Redis with a 30s TTL, and returns JSON response (`source: "db"`).

---

## 5. Infrastructure as Code (Terraform) Setup

Infrastructure is provisioned using Terraform in `infra/`:

```
infra/
├── environments/
│   └── dev/                  # Environment root module & S3 backend
└── modules/
    ├── vpc/                  # Multi-AZ VPC and Public Subnets (ap-south-1a & 1b)
    ├── internet_gateway/     # AWS Internet Gateway
    ├── route_table/          # Public Route Tables and Associations
    ├── security_group/       # ALB Security Group & ECS Tasks Security Group
    ├── alb/                  # Application Load Balancer & IP-based Target Groups
    ├── service_discovery/    # AWS Cloud Map Private DNS Namespace (order-platform.local)
    ├── efs/                  # AWS EFS File System & POSIX Access Point for Postgres
    ├── ecs/                  # ECS Cluster, Task Definitions, Fargate Services
    ├── iam_role/             # ECS Execution Role & Task Roles
    └── oidc/                 # GitHub Actions AWS OIDC Role for ECS Deployment
```

### Terraform Execution

1. Initialize Terraform remote state (S3 backend with native state locking `use_lockfile = true`):
   ```bash
   cd infra/environments/dev
   terraform init
   ```

2. Review planned resource changes:
   ```bash
   terraform plan
   ```

3. Provision AWS infrastructure:
   ```bash
   terraform apply
   ```

Outputs will display `alb_dns_name` and `github_actions_role_arn`.

---

## 6. Secrets Management (AWS SSM Parameter Store)

Secrets (`PG_PASSWORD`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD`) are stored in AWS SSM Parameter Store under `/order-platform/*`.

### Native ECS Secret Resolution
No local shell scripts or plaintext files are used. ECS Task Definitions bind parameters natively:

```json
"secrets": [
  {
    "name": "PGPASSWORD",
    "valueFrom": "arn:aws:ssm:ap-south-1:*:parameter/order-platform/pg-password"
  }
]
```

At task initialization, the ECS agent uses `ecsTaskExecutionRole` to fetch the parameter from SSM and populates the container process environment.

---

## 7. Automated CI/CD Pipelines

Pipelines are declared in `.github/workflows/`:

### CI Workflow (`.github/workflows/ci.yaml`)
- `gitleaks` repository secret scanning.
- `npm audit` dependency security checks.
- Docker image build with dual tagging (`:scan` for local scan, `${{ github.sha }}` for remote registry).
- `trivy` container vulnerability scanning.
- Docker Hub image push and Discord notification.

### CD Workflow (`.github/workflows/cd.yaml`)
- Passwordless AWS authentication via OpenID Connect (`aws-actions/configure-aws-credentials`).
- Task definition rendering with new `${{ github.sha }}` image tag via `aws-actions/amazon-ecs-render-task-definition`.
- Fargate rolling service deployment via `aws-actions/amazon-ecs-deploy-task-definition`.
- Automated health check verification and circuit-breaker rollback on failure.

---

## 8. Operational Troubleshooting & CloudWatch Commands

### Viewing Container Logs in CloudWatch
Container output is streamed to CloudWatch Log Group `/ecs/order-platform`:

```bash
# View API task logs
aws logs tail /ecs/order-platform --log-stream-prefix api --follow --region ap-south-1

# View Worker task logs
aws logs tail /ecs/order-platform --log-stream-prefix worker --follow --region ap-south-1
```

### Inspecting ECS Services & Tasks
```bash
# List running tasks in cluster
aws ecs list-tasks --cluster order-platform-cluster --region ap-south-1

# Describe API service status
aws ecs describe-services --cluster order-platform-cluster --services api --region ap-south-1
```

### Testing ALB Endpoints
```bash
# Test API Health Endpoint
curl -i http://<ALB_DNS_NAME>/health

# Fetch Posts List (Check source: "db" vs "cache")
curl -i http://<ALB_DNS_NAME>/api/posts
```
