# Order Platform — Production Architecture & Operations Manual

A distributed, enterprise-grade cloud application deployed on AWS demonstrating:
- **Stateless Tier (AWS ECS Fargate)**: Frontend (React SPA / Nginx), API (Node.js / Express), Worker (RabbitMQ Background Consumer).
- **Stateful Tier (AWS EC2 in Private Subnet)**: PostgreSQL (Relational DB), Redis (In-Memory Cache), RabbitMQ (Message Broker) with persistent EBS disk storage.
- **Traffic Routing (AWS Application Load Balancer)**: Dual-AZ public ingress on Port 80 with path-based routing (`/` $\rightarrow$ Frontend, `/api/*` $\rightarrow$ API Backend).
- **Zero-Plaintext Security**: Encrypted secrets fetched dynamically from AWS SSM Parameter Store & AWS Secrets Manager.

---

## 1. System Architecture Blueprint

```
                        [ Internet / User Browser ]
                                     │
                                     ▼ (Port 80)
┌────────────────────────────────────────────────────────────────────────┐
│                    Application Load Balancer (ALB)                     │
│                        (Public Subnets Dual-AZ)                        │
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

## 2. Component & Sizing Specification

| Component | Layer / Host | Sizing | Network / Port | Storage / Persistence |
|---|---|---|---|---|
| `frontend` | **ECS Fargate** | 0.25 vCPU / 512 MiB | ALB Default Path `/*` (Port 80) | Ephemeral |
| `api` | **ECS Fargate** | 0.25 vCPU / 512 MiB | ALB Listener Path `/api/*` & `/health` (Port 4000) | Ephemeral |
| `worker` | **ECS Fargate** | 0.25 vCPU / 512 MiB | Internal Queue Consumer (No open ports) | Ephemeral |
| `postgres` | **EC2 Instance** | `t3.small` (Shared) | `10.0.1.X:5432` (Private Subnet only) | Persistent EBS Disk (`gp3` / 20GB) |
| `redis` | **EC2 Instance** | `t3.small` (Shared) | `10.0.1.X:6379` (Private Subnet only) | Named volume (`redisdata`) |
| `rabbitmq` | **EC2 Instance** | `t3.small` (Shared) | `10.0.1.X:5672` (Private Subnet only) | Named volume (`rabbitmqdata`) |

---

## 3. Distributed Request Flow Patterns

### 1. Write Path (Asynchronous Decoupled Processing)
1. Browser sends `POST /api/posts {title, content}` to the ALB.
2. ALB forwards `/api/posts` to the **API Task on ECS Fargate**.
3. API task publishes the message to **RabbitMQ on EC2 (`10.0.1.X:5672`)** and immediately responds `HTTP 202 Accepted {"status":"queued"}`.
4. **Worker Task on ECS Fargate** pulls the message from RabbitMQ asynchronously.
5. Worker inserts the record into **PostgreSQL on EC2 (`10.0.1.X:5432`)** and clears the Redis cache key (`posts:all`).

### 2. Read Path (Cache-Aside Pattern)
1. Browser sends `GET /api/posts` to the ALB.
2. ALB routes request to the API task.
3. API checks **Redis on EC2 (`10.0.1.X:6379`)**:
   - **Cache Hit**: Returns cached JSON directly (`source: "cache"`).
   - **Cache Miss**: Queries PostgreSQL (`10.0.1.X:5432`), writes result to Redis with 30s TTL, and returns response (`source: "db"`).

---

## 4. How to Run Locally (Docker Compose)

To test the entire stack on your local machine with a single command:

```bash
# 1. Build and start all 6 services locally
docker compose up -d --build

# 2. Verify containers are healthy
docker compose ps
```

* **Frontend UI**: [http://localhost](http://localhost)
* **API Health Check**: [http://localhost:4000/health](http://localhost:4000/health)
* **RabbitMQ Management Dashboard**: [http://localhost:15672](http://localhost:15672) (User: `user`, Pass: `password123`)

---

## 5. How to Deploy to AWS

### Step 1: Upload Credentials to AWS SSM Parameter Store
Run the interactive helper script to store encrypted passwords in SSM:

```bash
bash infra/ssm_data_upload.sh
```

### Step 2: Provision Infrastructure via Terraform

```bash
cd infra/environments/dev

# 1. Initialize Terraform remote state & providers
terraform init

# 2. Preview resources
terraform plan

# 3. Apply infrastructure
terraform apply -auto-approve
```

Upon completion, Terraform will output your live endpoints:
```text
alb_dns_name            = "http://order-platform-alb-xxxx.ap-south-1.elb.amazonaws.com"
stateful_ec2_private_ip = "10.0.1.238"
deployed_image_tag      = "378b552df7efb62e0848df1220e2b8efcd911ee1"
```

---

## 6. How to Test Your Live AWS Application

1. **Open Frontend Web UI**:
   Paste the `alb_dns_name` URL into your web browser:
   ```text
   http://order-platform-alb-xxxx.ap-south-1.elb.amazonaws.com/
   ```

2. **Verify API Endpoint via `curl`**:
   ```bash
   # 1. Health Check
   curl -i http://<ALB_DNS_NAME>/health

   # 2. Create a Post (Write Path)
   curl -i -X POST http://<ALB_DNS_NAME>/api/posts \
     -H "Content-Type: application/json" \
     -d '{"title":"First Post","content":"Hello from AWS ECS Fargate!"}'

   # 3. Fetch Posts (Read Path)
   curl -i http://<ALB_DNS_NAME>/api/posts
   ```

---

## 7. Operational Commands & Log Streaming

### Stream Container Logs in Real Time via CloudWatch
```bash
# Frontend Web Server Logs
aws logs tail /ecs/order-platform-frontend --follow --region ap-south-1

# API Backend Logs
aws logs tail /ecs/order-platform-api --follow --region ap-south-1

# Worker Queue Consumer Logs
aws logs tail /ecs/order-platform-worker --follow --region ap-south-1
```

### Deploy a New Version (Passing New Git SHA)
```bash
cd infra/environments/dev
terraform apply -var="image_tag=<new_commit_sha>" -auto-approve
```

---

## 8. How to Teardown Infrastructure (Zero Cost)

When you are done testing and want to avoid AWS hourly charges:

```bash
cd infra/environments/dev
terraform destroy -auto-approve
```
