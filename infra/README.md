# Order Platform — Infrastructure (Phase 2)

Terraform-managed infrastructure for the Order Platform application. This
covers provisioning only — the application itself (Docker Compose stack:
frontend, api, worker, Postgres, Redis, RabbitMQ) is unchanged from Phase
1. What changes in this phase is *how the server that runs it gets
created*, and how deploys reach that server.

## What this phase does and does not cover

**In scope for Phase 2:**
- A VPC with one public subnet, internet gateway, and route table.
- One EC2 instance in that public subnet, running Docker + Docker Compose.
- A security group restricting inbound access to what's actually needed.
- A GitHub Actions workflow that builds images, pushes them to Docker Hub,
  then SSHes into the EC2 instance to pull and redeploy.

**Explicitly not in scope yet** (deferred to later phases, not forgotten):
- Dynamic secrets from AWS Secrets Manager / SSM — secrets for this phase
  live in a `.env` file that exists only on the EC2 instance, never
  committed to Git.
- Auto-scaling, load balancing, multi-AZ — this is a single instance.
- Kubernetes of any kind — that's Phase 3.

## Folder structure

```
infra/
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── backend.tf
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── security_group/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── README.md
```

### Why modules are separated from environments

A module is a reusable definition — "how to build a VPC," parameterized
by CIDR block and subnet count. An environment is where that module gets
called with specific values. `environments/dev/main.tf` should contain
only module calls (`module "vpc" { source = "../../modules/vpc" ... }`),
not raw resource blocks. This means adding `environments/staging` later is
a matter of copying the environment folder and adjusting
`terraform.tfvars` — the module definitions themselves don't change or
duplicate.

### What belongs in each file, by convention

| File | Purpose |
|---|---|
| `main.tf` | Resource blocks (inside a module) or module calls (inside an environment). |
| `variables.tf` | Declares every input this file/module accepts — type and description, no hardcoded values. |
| `outputs.tf` | Values exposed upward — e.g. the `vpc` module outputs `vpc_id` and `public_subnet_id` so the `ec2` module can consume them as inputs. |
| `terraform.tfvars` | The actual values for this specific environment (region, CIDR ranges, instance type). This is the file that changes between environments; everything else stays identical. |
| `backend.tf` | State backend configuration — see below. |

## State backend

Local state (`terraform.tfstate` on disk, gitignored) is the starting
point here, since there's a single person applying changes. This stops
being safe the moment more than one writer touches the same state — most
relevantly, if GitHub Actions is ever given permission to run `terraform
apply` itself, rather than only building/pushing images and SSH-deploying.
Two concurrent writers to local state with no locking risks state
corruption or conflicting changes silently overwriting each other.

**Decision for this phase:** GitHub Actions does not run `terraform
apply`. All infrastructure changes are applied manually, from a developer
machine, using local state. CI/CD in this phase is limited to
build-image → push-to-registry → SSH-deploy, entirely separate from the
Terraform workflow. If this decision changes later (CI applying
Terraform), migrate to an S3 backend with a DynamoDB lock table before
that happens, not after — state migration mid-project is its own
undertaking and is easier to do before any drift accumulates.

## Networking design

- One VPC, one public subnet — everything for this phase lives in a
  single subnet with a route to an internet gateway. No private subnet
  yet, since there's nothing (a database, an internal service) that needs
  to be shielded from the internet at this stage — Postgres/Redis/
  RabbitMQ all run as containers on the same EC2 instance, reachable only
  via Docker's internal network, not exposed to the VPC at all.
- Security group inbound rules should be scoped to exactly what's needed:
  SSH (22) restricted to a known IP, not `0.0.0.0/0`; application ports
  (3000 for frontend, 4000 for API) open as required; RabbitMQ's
  management UI (15672) should be a deliberate choice, not a default —
  decide whether it needs to be internet-reachable at all versus only
  reachable via an SSH tunnel.

## Secrets handling for this phase

Application secrets (Postgres password, RabbitMQ credentials) are not
committed to Git and are not placed in `docker-compose.yml` directly. They
live in a `.env` file that exists only on the EC2 instance's filesystem,
referenced by `docker-compose.yml` via `env_file: .env`. This file is
created once on the instance (manually, or via a Terraform
`remote-exec`/`null_resource` provisioner during initial setup) and is
never part of the CI/CD pipeline's checked-out code. This is the same
mechanism as the `.env`-bind-mount pattern seen in production compose
files elsewhere — the difference in later phases is only *where the
values come from* (dynamically fetched from Secrets Manager/SSM instead
of a static file), not the overall approach.

## CI/CD flow for this phase

```
git push
   │
   ▼
GitHub Actions
   │
   ├─ build frontend, api, worker images
   ├─ tag with git commit SHA (not `:latest` — see below)
   ├─ push to Docker Hub
   │
   ▼
SSH into EC2 instance
   │
   ├─ docker compose pull
   └─ docker compose up -d
```

### Why image tags use the commit SHA, not `latest`

Tagging every build `:latest` means `docker compose pull` has no way to
tell whether anything actually changed, and a rollback means manually
figuring out which previous image was actually good. Tagging with the Git
SHA (or a pipeline-incremented version) makes every deploy traceable to an
exact commit and makes rollback a matter of redeploying a known-good tag,
not guesswork. This is a small addition to the workflow now and expensive
to retrofit once `:latest` habits are established.

### Why `docker compose pull && up -d`, not `down` then `up`

`down` followed by `up` tears down every container before starting any of
them back up, causing a full-stack outage for however long that takes.
`pull` followed by `up -d` only recreates the containers whose image
actually changed, leaving unaffected services running. For a single-
instance, low-traffic Phase 2 setup this difference is minor in practice,
but it's the correct default habit to build now rather than later.

## Prerequisites

- Terraform CLI installed locally.
- An AWS account and credentials configured locally (`aws configure` or
  equivalent) with permissions to create VPC, EC2, and security group
  resources.
- An SSH key pair — the public key provisioned onto the EC2 instance via
  Terraform, the private key held securely (locally, and as a GitHub
  Actions secret for the SSH-deploy step).
- A Docker Hub account/repository for the built images.

## Standard workflow

```bash
cd infra/environments/dev
terraform init
terraform plan
terraform apply
```

`terraform plan` should always be reviewed before `apply` — treat a plan
showing unexpected destroys or replacements as a stop signal, not
something to apply through.

## What changes in Phase 3

The application and its containerized architecture do not change. What
changes is the provisioning and deployment mechanism: EC2 gets replaced by
EKS, SSH-based deploy gets replaced by ArgoCD reconciling from Git, and
the static `.env` file on the instance gets replaced by dynamic secrets
(Secrets Manager/SSM, delivered via Sealed Secrets or External Secrets
Operator). Decide the Phase 3 secrets approach before starting that phase,
not after ArgoCD is already wired up — see `ARCHITECTURE.md` for the
full reasoning on why that sequencing matters.