# Order Platform — AWS EC2 + GitHub Actions OIDC + SSM CD

A 6-container distributed cloud application demonstrating **cache-aside reads**, **producer/consumer queue-based async writes**, **Terraform Infrastructure-as-Code**, **AWS EC2 deployment**, **GitHub Actions OIDC passwordless authentication**, and **AWS SSM Run Command agentless CD** (no open SSH port required).

---

## High-Level System Architecture

```
                    Public Internet
                          |
                   :3000 (frontend)  :4000 (api)
                          |
              +-----------------------------------+
              |         EC2 (t3.micro)            |
              |       Elastic IP (static)         |
              |                                   |
              |  [frontend]         [api]          |
              |                      |             |
              |               [Redis]  [RabbitMQ] |
              |                            |       |
              |                        [worker]    |
              |                            |       |
              |                      [PostgreSQL]  |
              +-----------------------------------+
```

**Write path** — `POST /api/posts` → API publishes to `posts_queue` → returns `202 Queued` → Worker inserts to Postgres and deletes Redis cache key.

**Read path** — `GET /api/posts` → API checks Redis → cache hit returns immediately; cache miss queries Postgres, stores in Redis (30s TTL), returns response.

---

## Application Services

| Service    | Image                                                  | Port             | Notes                               |
|------------|--------------------------------------------------------|------------------|-------------------------------------|
| `frontend` | `<DOCKERHUB_USERNAME>/order-platform-frontend:<SHA>`   | `3000->80`       | React (Vite) UI                     |
| `api`      | `<DOCKERHUB_USERNAME>/order-platform-api:<SHA>`        | `4000`           | Express — read/write/search         |
| `worker`   | `<DOCKERHUB_USERNAME>/order-platform-worker:<SHA>`     | none             | RabbitMQ consumer, writes to PG     |
| `postgres` | `postgres:16-alpine`                                   | `127.0.0.1:5432` | DB, volume `pgdata`                 |
| `redis`    | `redis:7-alpine`                                       | `127.0.0.1:6379` | Cache, 30s TTL                      |
| `rabbitmq` | `rabbitmq:3-management-alpine`                         | `127.0.0.1:5672` | Queue; mgmt UI `:15672` (SSH tunnel)|

---

## Infrastructure (Terraform)

### Directory Layout

```
infra/
+-- ssm_data_upload.sh            # One-time: push secrets to SSM Parameter Store
+-- environments/
|   +-- dev/
|       +-- main.tf               # Root module -- wires all modules
|       +-- variables.tf          # ami_id, ssh_ip
|       +-- terraform.tfvars      # Actual variable values
|       +-- outputs.tf            # EIP, GitHub Actions role ARN, EC2 instance ID
|       +-- terraform.tf          # Provider (aws, ap-south-1)
|       +-- backend.tf            # S3 remote state + native locking
+-- modules/
    +-- vpc/                      # VPC 10.0.0.0/16 + public subnet 10.0.1.0/24 (ap-south-1a)
    +-- Internet_gateway/         # IGW attached to VPC
    +-- route_table/              # Route 0.0.0.0/0 -> IGW; associated to public subnet
    +-- security_group/           # Ingress per service; SSH locked to ssh_ip
    +-- elastic_ip/               # Static EIP -- stable public IP across reboots
    +-- ec2/                      # t3.micro Ubuntu, IAM profile, user_data (Docker + AWS CLI)
    +-- iam_role/                 # EC2 role: SSM core + SSM param read + S3 deploy state R/W
    +-- oidc/                     # GitHub Actions role: OIDC trust + SSM SendCommand + S3 write
```

### Module Details

#### `vpc`
VPC `10.0.0.0/16` with a single public subnet `10.0.1.0/24` in `ap-south-1a`. `map_public_ip_on_launch = true`.

#### `Internet_gateway`
IGW attached to the VPC. The route table routes `0.0.0.0/0` through it.

#### `security_group`

| Rule     | Source        | Port(s) |
|----------|---------------|---------|
| HTTP     | `0.0.0.0/0`  | 80      |
| HTTPS    | `0.0.0.0/0`  | 443     |
| API      | `0.0.0.0/0`  | 4000    |
| Frontend | `0.0.0.0/0`  | 3000    |
| SSH      | `var.ssh_ip` | 22      |
| Postgres | VPC CIDR     | 5432    |
| RabbitMQ | VPC CIDR     | 5672    |
| Redis    | VPC CIDR     | 6379    |
| Outbound | all          | all     |

#### `elastic_ip`
Allocates a static EIP and associates it to the EC2 instance. Survives stop/start cycles.

#### `ec2`
`t3.micro` Ubuntu in the public subnet. `user_data.sh.tpl` bootstraps on first boot:

1. Installs Docker CE + Compose V2 plugin (from Docker's official apt repo)
2. Installs AWS CLI v2
3. Adds `ubuntu` to the `docker` group
4. SSM Agent is pre-installed on Ubuntu AMIs — no extra step needed

#### `iam_role` (EC2 instance role)

| Policy | Scope |
|--------|-------|
| `AmazonSSMManagedInstanceCore` (managed) | SSM Agent register + receive commands |
| `ssm:GetParameter`, `ssm:GetParameters` | `/order-platform/*` app secrets |
| `ssm:GetParametersByPath` | `/order-platform/*` used by `fetch_secrets.sh` |
| `s3:GetObject`, `s3:PutObject` | `deploy/dev/versions.json` version history |
| `s3:GetObject`, `s3:ListBucket` | `deploy/dev/artifacts/*` deploy files |

#### `oidc` (GitHub Actions role)

| Policy | Scope |
|--------|-------|
| OIDC trust: `token.actions.githubusercontent.com` | Branches `main`, `dev`, `oidc` only — no fork PRs |
| `ssm:DescribeInstanceInformation` | `*` (AWS limitation, cannot scope to instance) |
| `ssm:SendCommand` | Specific EC2 instance ARN |
| `ssm:GetCommandInvocation`, `ssm:ListCommandInvocations` | `ssm:*` (CommandId unknown before send) |
| `s3:PutObject` | `deploy/dev/artifacts/*` |

### Terraform Outputs

| Output | Use |
|--------|-----|
| `order_platform_ec2_public_ip` | SSH and browser access (static EIP) |
| `github_actions_role_arn` | GitHub repo variable `AWS_ROLE_ARN` |
| `ec2_instance_id` | GitHub repo variable `EC2_INSTANCE_ID` |

---

## Prerequisites

1. **AWS CLI** configured locally (permissions: IAM, VPC, EC2, SSM, S3, EIP)
2. **Terraform >= 1.10** (`use_lockfile = true` requires it)
3. **S3 bucket** for Terraform remote state: `order-platform-tf-state-891274465984`
4. **SSH key pair** — public key at `infra/environments/dev/order_platform_key.pub`:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/order_platform_key
   cp ~/.ssh/order_platform_key.pub infra/environments/dev/order_platform_key.pub
   ```
5. **Docker Hub account** with repos for `order-platform-api`, `order-platform-worker`, `order-platform-frontend`

---

## Setup Guide

### Step 1 — Upload Secrets to AWS SSM Parameter Store

Run once from your local machine. Prompts interactively and writes as `SecureString`:

```bash
bash infra/ssm_data_upload.sh
```

Creates:
- `/order-platform/pg-password`
- `/order-platform/rabbitmq-password`
- `/order-platform/rabbitmq-user`
- `/order-platform/dockerhub-token`
- `/order-platform/dockerhub-username`

Verify:
```bash
aws ssm describe-parameters \
  --region ap-south-1 \
  --parameter-filters Key=Name,Option=BeginsWith,Values=/order-platform
```

---

### Step 2 — Provision AWS Infrastructure

```bash
cd infra/environments/dev
terraform init
terraform plan
terraform apply
```

Copy the three output values — you need them in Step 3.

---

### Step 3 — Configure GitHub Repository

**Settings -> Secrets and variables -> Actions -> Variables:**

| Variable | Value |
|----------|-------|
| `AWS_ROLE_ARN` | `github_actions_role_arn` output |
| `EC2_INSTANCE_ID` | `ec2_instance_id` output |

**Settings -> Secrets and variables -> Actions -> Secrets:**

| Secret | Value |
|--------|-------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Your Docker Hub access token |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL |

---

### Step 4 — Upload Deploy Artifacts to S3

The CD workflow tells EC2 (via SSM) to pull deploy files from S3. Upload once, re-upload whenever scripts or `docker-compose.yml` change:

```bash
# From project root
bash scripts/dev/manual.sh
```

Uploads to `s3://order-platform-tf-state-891274465984/deploy/dev/artifacts/`:
- `docker-compose.yml`
- `scripts/dev/deploy.sh`
- `scripts/dev/fetch_secrets.sh`
- `scripts/dev/rollback.sh`
- `scripts/dev/update-version.sh`

---

### Step 5 — Run CI

**GitHub -> Actions -> CI - Build and Push Images -> Run workflow**

| Job | What it does |
|-----|--------------|
| `scan-secrets` | `gitleaks` on full git history |
| `build-backend` | `npm audit`, Docker build (`:scan` + `:<sha>`), Trivy (CRITICAL/HIGH), push `:<sha>` |
| `build-worker` | Same as backend |
| `build-frontend` | Same; `VITE_API_URL=/api` build arg; CRITICAL-only Trivy |
| `notify-discord` | Pass/fail embed to Discord |

---

### Step 6 — Run CD

**GitHub -> Actions -> CD - Deploy to EC2 (dev) via OIDC + SSM -> Run workflow**

**The OIDC + SSM flow — no SSH keys stored anywhere:**

```
GitHub Actions Runner
  |
  | 1. Mints OIDC token ("this run = repo X, branch oidc")
  v
AWS STS  ->  sts:AssumeRoleWithWebIdentity
  |
  | 2. Returns short-lived credentials for github_actions_cd role
  v
AWS SSM  ->  ssm:SendCommand
  |
  | 3. Queues shell commands for the EC2 instance
  v
EC2 SSM Agent  (polls outbound :443 -- no inbound port 22 needed)
  |
  | 4. Runs on EC2:
  |    a. aws s3 sync -> pull compose + scripts from S3
  |    b. source fetch_secrets.sh -> read SSM params into env
  |    c. docker compose pull && up -d
  |    d. health check loop (15 attempts x 3s)
  |    e. update-version.sh -> write version history to S3
  v
GitHub Actions Runner
  |
  | 5. ssm:GetCommandInvocation -> print stdout/stderr
  |    fail job if status != Success
```

CD step breakdown:

| Step | Purpose |
|------|---------|
| Configure AWS credentials via OIDC | Exchange OIDC token for temporary AWS credentials |
| Sanity check auth | `sts get-caller-identity` — confirms OIDC worked |
| Print deploy target info | Prints instance ID, role ARN, commit SHA; fails if `EC2_INSTANCE_ID` unset |
| Verify SSM registration | Checks SSM Agent is `Online`; fails fast if not |
| Build SSM command payload | Writes `params.json` — the 4 commands to run on EC2 |
| Send deploy command via SSM | `ssm:SendCommand`; captures Command ID |
| Wait for SSM command | Waits, prints EC2 stdout/stderr, fails if status != `Success` |

---

### Step 7 — Verify the Deployment

```bash
# API health
curl http://<EIP>/health

# Posts list (check source: "db" vs "cache")
curl http://<EIP>:4000/api/posts

# Frontend
open http://<EIP>:3000
```

---

## Operational Reference

### Manual Rollback

If a deploy failed its health check and you need the last known-good version:

```bash
ssh -i ~/.ssh/order_platform_key ubuntu@<EIP>
cd /home/ubuntu/order-platform
bash scripts/dev/rollback.sh
```

`rollback.sh` reads `versions.json` from S3 (`current` = last successful sha), pulls that tag, and redeploys it.

### Version History

Updated in S3 after every successful deploy:

```json
{
  "current":  "<last successful sha>",
  "previous": "<one before>",
  "oldest":   "<two before>"
}
```

```bash
aws s3 cp s3://order-platform-tf-state-891274465984/deploy/dev/versions.json - --region ap-south-1
```

### Container Logs (on EC2)

```bash
docker compose -f /home/ubuntu/order-platform/docker-compose.yml logs -f
docker compose -f /home/ubuntu/order-platform/docker-compose.yml logs -f api
docker compose -f /home/ubuntu/order-platform/docker-compose.yml logs -f worker
```

### Inspect SSM Command Output

```bash
aws ssm get-command-invocation \
  --command-id <COMMAND_ID> \
  --instance-id <EC2_INSTANCE_ID> \
  --query "{Status:Status,StdOut:StandardOutputContent,StdErr:StandardErrorContent}" \
  --output json \
  --region ap-south-1
```

### Check SSM Agent Status

```bash
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=<EC2_INSTANCE_ID>" \
  --region ap-south-1
```

---

## Tear Down

```bash
cd infra/environments/dev
terraform destroy
```

> **Note:** The S3 bucket (`order-platform-tf-state-891274465984`) is not managed by this Terraform config and will not be destroyed. Delete it manually if needed.

---

## Branch Map

| Branch | Description |
|--------|-------------|
| `main` | Base source |
| `oidc` | **Current** — EC2 + GitHub OIDC + SSM Run Command CD (no stored SSH keys) |
| `ec2-ci-ssh_cd` | EC2 + SSH-based CD (SSH key stored in GitHub Secrets) |
| `fargate-ecs` | AWS ECS Fargate (multi-AZ, ALB, Cloud Map, EFS) — in progress |
| `local` | Local Docker Compose only |
