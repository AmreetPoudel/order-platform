# Order Platform — Architecture & Operations Guide

A scalable cloud platform built with a **Stateless & Stateful Hybrid Architecture**:
- **Stateless Services (AWS ECS Fargate)**: Frontend (React/Nginx), API (Node/Express), Worker (RabbitMQ Consumer).
- **Stateful Services (AWS EC2)**: PostgreSQL (Relational DB), Redis (Cache), RabbitMQ (Message Broker) in Private Subnet with EBS persistent storage.
- **Networking & Routing**: Application Load Balancer (ALB) with path-based routing (`/` $\rightarrow$ Frontend, `/api/*` $\rightarrow$ API Backend).
- **Automation**: Terraform Infrastructure-as-Code & GitHub Actions CI/CD with rolling zero-downtime deployments.

---

## 1. System Architecture

```
                        [ Internet / User Browser ]
                                     │
                                     ▼ (Port 80)
┌────────────────────────────────────────────────────────────────────────┐
│                    Application Load Balancer (ALB)                     │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                   ┌─────────────────┴─────────────────┐
    Path: / (Default)                                   │ Path: /api/* & /health
                   ▼                                   ▼
┌─────────────────────────────────────┐ ┌─────────────────────────────────────┐
│             ECS FARGATE             │ │             ECS FARGATE             │
│        Frontend (React/Nginx)       │ │          API Backend (Node)         │
│               Port 80               │ │              Port 4000              │
└─────────────────────────────────────┘ └──────────────────┬──────────────────┘
                                                           │
                                        (Private Subnet)   │ (DB & Cache Queries)
                                                           ▼
                                ┌─────────────────────────────────────────────┐
                                │            STATEFUL EC2 INSTANCE            │
                                │            (In Private Subnet)              │
                                │                                             │
                                │   PostgreSQL         Redis       RabbitMQ   │
                                │    (:5432)          (:6379)      (:5672)    │
                                └──────────────────────────▲───────────▲──────┘
                                                           │           │
                                                           │ (Consume) │
                                                ┌──────────┴───────────┴──────┐
                                                │         ECS FARGATE         │
                                                │        Worker Task          │
                                                └─────────────────────────────┘
```

---

## 2. Microservice & Layer Summary

| Component | Layer / Host | Sizing | Network / Port | Storage / Persistence |
|---|---|---|---|---|
| `frontend` | **ECS Fargate** | 0.25 vCPU / 512 MB | ALB Default Path `/*` (Port 80) | Ephemeral |
| `api` | **ECS Fargate** | 0.25 vCPU / 512 MB | ALB Listener Path `/api/*` & `/health` (Port 4000) | Ephemeral |
| `worker` | **ECS Fargate** | 0.25 vCPU / 512 MB | Internal Queue Consumer (No HTTP port) | Ephemeral |
| `postgres` | **EC2 Instance** | `t3.small` (Shared) | `10.0.1.X:5432` (Private Subnet only) | Persistent EBS Disk (`gp3`) |
| `redis` | **EC2 Instance** | `t3.small` (Shared) | `10.0.1.X:6379` (Private Subnet only) | Persistent Volume (`redisdata`) |
| `rabbitmq` | **EC2 Instance** | `t3.small` (Shared) | `10.0.1.X:5672` (Private Subnet only) | Persistent Volume (`rabbitmqdata`) |

---

## 3. Distributed Application Flow Patterns

### 1. Write Path (Asynchronous Decoupled Writes)
1. Browser sends `POST /api/posts {title, content}` to the public ALB.
2. ALB forwards the request to the `api` target group on port `4000`.
3. `api` task publishes a persistent message to `posts_queue` on RabbitMQ (`EC2:5672`).
4. `api` immediately responds with `HTTP 202 Queued`.
5. `worker` task pulls the message from RabbitMQ and writes the record to PostgreSQL (`EC2:5432`).
6. `worker` invalidates the Redis cache (`EC2:6379`).

### 2. Read Path (Cache-Aside Pattern)
1. Browser sends `GET /api/posts` to the ALB.
2. ALB forwards to `api` target group on port `4000`.
3. `api` checks Redis (`EC2:6379`) for key `posts:all`:
   - **Cache Hit**: Returns cached JSON directly (`source: "cache"`).
   - **Cache Miss**: Queries PostgreSQL (`EC2:5432`), writes result to Redis with 30s TTL, and returns response (`source: "db"`).

---

## 4. Repository & Terraform Structure

```
├── .github/
│   └── workflows/
│       ├── ci.yaml                   # Image build, Trivy scan, Docker Hub push
│       └── cd.yaml                   # Zero-downtime rolling deployment to ECS Fargate
├── backend/                          # Express.js REST API
├── frontend/                         # React Web App (Vite + Nginx)
├── worker/                           # RabbitMQ Background Consumer
├── db/                               # PostgreSQL init.sql schema
├── docker-compose.yml                # Full stack local development
├── docker-compose.stateful.yml       # EC2 compose for Postgres, Redis, RabbitMQ
├── modules/
│   ├── VPC/                          # VPC (10.0.0.0/16)
│   ├── public_subnet/                # Multi-AZ Public Subnets (ap-south-1a & 1b)
│   ├── private_subnet/               # Multi-AZ Private Subnets (ap-south-1a & 1b)
│   ├── internet_gateway/             # Internet Gateway
│   ├── nat_gateway/                  # NAT Gateways for private subnet egress
│   ├── route_table/                  # Public and Private route tables
│   ├── SG/                           # ALB Security Group
│   ├── ALB/                          # Application Load Balancer
│   ├── dockerhub_secret/             # Secrets Manager Docker Hub credentials
│   ├── stateful_ec2/                 # EC2 instance & SG for Postgres, Redis, RabbitMQ
│   └── ECS/                          # ECS Cluster, Task Definitions, Services, Target Groups
└── infra/
    └── environments/
        └── dev/                      # Root environment module & S3 backend
            ├── main.tf
            └── outputs.tf
```

---

## 5. Deployment Instructions

### Step 1: Provision Infrastructure via Terraform
```bash
cd infra/environments/dev

# 1. Initialize backend & modules
terraform init

# 2. Review infrastructure changes
terraform plan

# 3. Apply changes to AWS
terraform apply
```

### Step 2: Access Endpoints
Upon successful apply, Terraform outputs:
```text
alb_dns_name            = "http://order-platform-alb-xxxx.ap-south-1.elb.amazonaws.com"
stateful_ec2_private_ip = "10.0.1.x"
api_service_name        = "order-platform-api-service"
frontend_service_name   = "order-platform-frontend-service"
worker_service_name     = "order-platform-worker-service"
```

1. Open `http://<alb_dns_name>/` in your browser to view the **React Web UI**.
2. Visit `http://<alb_dns_name>/health` to verify API health (`{"status":"ok"}`).

---

## 6. Secrets Management (AWS Systems Manager)

Secrets are securely injected from AWS SSM Parameter Store at container startup via ECS Task Execution Role:
- `/order-platform/pg-password` $\rightarrow$ `PGPASSWORD`
- `/order-platform/rabbitmq-user` $\rightarrow$ `RABBITMQ_USER`
- `/order-platform/rabbitmq-password` $\rightarrow$ `RABBITMQ_PASSWORD`

Upload secrets via the provided helper script:
```bash
bash infra/ssm_data_upload.sh
```

---

## 7. CI/CD Workflows

### CI Pipeline (`.github/workflows/ci.yaml`)
- Gitleaks secret scan.
- NPM dependency security audit.
- Docker image build & Trivy vulnerability scan.
- Push images to Docker Hub (`${DOCKERHUB_USERNAME}/order-platform-<service>:${SHA}`).

### CD Pipeline (`.github/workflows/cd.yaml`)
- Authenticates with AWS.
- Triggers zero-downtime rolling updates on all 3 ECS Fargate services (`aws ecs update-service --force-new-deployment`).
- Waits for tasks to stabilize and verifies ALB endpoint response.

---

## 8. Operational & Monitoring Commands

### Stream Container Logs from CloudWatch
```bash
# Frontend Logs
aws logs tail /ecs/order-platform-frontend --follow --region ap-south-1

# API Backend Logs
aws logs tail /ecs/order-platform-api --follow --region ap-south-1

# Worker Logs
aws logs tail /ecs/order-platform-worker --follow --region ap-south-1
```

### Inspect ECS Services
```bash
aws ecs list-tasks --cluster order-platform-cluster --region ap-south-1
aws ecs describe-services --cluster order-platform-cluster --services order-platform-api-service --region ap-south-1
```
