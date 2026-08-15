# Order Platform — Production Hybrid Architecture (AWS ECS Fargate & EC2)

## 1. System Overview

This document specifies the **production hybrid architecture** for the Order Platform on AWS:
- **Stateless Compute (AWS ECS Fargate)**: Eliminates container host management for application layers. Tasks scale dynamically and deploy with zero downtime.
- **Stateful Compute (AWS EC2 in Private Subnet)**: Runs PostgreSQL, Redis, and RabbitMQ via Docker Compose with dedicated, high-performance EBS disk persistence.
- **Traffic Routing (AWS Application Load Balancer)**: Public dual-AZ entry point with path-based routing (`/` $\rightarrow$ Frontend, `/api/*` & `/health` $\rightarrow$ API).

---

## 2. Architecture Diagram

![Order Platform Architecture](./order_platform_architecture.png)

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

## 3. Tier & Component Specifications

### A. Stateless Tier (AWS ECS Fargate)
| Service | Image | CPU / RAM | Port | Purpose |
|---|---|---|---|---|
| `frontend` | `order-platform-frontend:latest` | 0.25 vCPU / 512 MiB | Port 80 | Static React SPA served via Nginx. |
| `api` | `order-platform-api:latest` | 0.25 vCPU / 512 MiB | Port 4000 | Express REST API. Handles read caching & publishes write events. |
| `worker` | `order-platform-worker:latest` | 0.25 vCPU / 512 MiB | None | Asynchronous queue consumer. Writes to DB & clears cache. |

### B. Stateful Tier (AWS EC2 in Private Subnet)
| Service | Container Image | Port | Persistence |
|---|---|---|---|
| `postgres` | `postgres:16-alpine` | Port 5432 | 20 GB `gp3` Persistent EBS Volume |
| `redis` | `redis:7-alpine` | Port 6379 | In-memory with RDB/AOF volume mount |
| `rabbitmq` | `rabbitmq:3-management-alpine` | Port 5672 / 15672 | Named persistent volume `rabbitmqdata` |

---

## 4. Request Flow Pipelines

### Write Flow (Asynchronous Queue Architecture)
1. **User Action**: Client submits a post via the Web UI (`POST /api/posts`).
2. **ALB Routing**: ALB forwards `/api/posts` to the `api` target group.
3. **Queue Ingestion**: `api` publishes JSON payload to `posts_queue` on RabbitMQ (`EC2:5672`) and immediately returns `HTTP 202 Queued`.
4. **Async Processing**: `worker` consumes the message from RabbitMQ, inserts the record into PostgreSQL (`EC2:5432`), and invalidates the Redis cache key (`posts:all`).

### Read Flow (Cache-Aside Pattern)
1. **User Action**: Client requests posts (`GET /api/posts`).
2. **ALB Routing**: ALB routes to `api` target group.
3. **Cache Check**: `api` queries Redis (`EC2:6379`).
   - **Hit**: Returns cached posts array (`source: "cache"`).
   - **Miss**: Queries PostgreSQL (`EC2:5432`), caches result in Redis with 30s TTL, and returns array (`source: "db"`).

---

## 5. Security & Network Isolation

1. **Private Subnets**: All ECS tasks and the Stateful EC2 instance reside in private subnets with no public IPs.
2. **Egress via NAT**: Outbound access (Docker image pulls, SSM parameter fetching) is routed through NAT Gateways in the public subnets.
3. **Security Groups**:
   - `alb_sg`: Allows 80/443 from `0.0.0.0/0`.
   - `ecs_task_sg`: Allows 80 & 4000 **only from `alb_sg`**.
   - `stateful_ec2_sg`: Allows 5432, 6379, and 5672 **only from within VPC / `ecs_task_sg`**.
4. **Secrets Management**: Credentials (`PGPASSWORD`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD`) are pulled directly by the ECS agent from AWS SSM Parameter Store at startup.