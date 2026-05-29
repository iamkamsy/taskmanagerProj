# Task Manager — Infrastructure (Part 3: ALB, ECS Services, Secrets)

Terraform configuration for the Task Manager production infrastructure on AWS.

- **Region:** `us-east-1`
- **Environment:** `prod`

> **Cost warning:** AWS resources created here may incur charges even without a NAT Gateway. ECR, ECS cluster, CloudWatch log storage, S3 state bucket, and DynamoDB lock table all have cost components. Review [AWS pricing](https://aws.amazon.com/pricing/) and monitor your billing dashboard.

---

## Architecture — Part 3 scope

Part 3 adds the ALB, target groups, listener rules, ECS task definitions, ECS services, security groups, and Secrets Manager secret containers on top of the Part 2 foundation.

**HTTP only.** HTTPS, ACM, and Route 53 are not configured in this part. They will be added in a later deployment part.

| Resource | Name / Value |
|---|---|
| VPC | `task-manager-prod-vpc` (`10.0.0.0/16`) |
| Public subnets | `task-manager-prod-public-1` (us-east-1a), `task-manager-prod-public-2` (us-east-1b) |
| Internet Gateway | `task-manager-prod-igw` |
| ECR backend | `task-manager-prod-backend` |
| ECR frontend | `task-manager-prod-frontend` |
| ECS cluster | `task-manager-prod-cluster` |
| CloudWatch logs | `/ecs/task-manager-prod-backend`, `/ecs/task-manager-prod-frontend` (7-day retention) |
| IAM task execution role | `task-manager-prod-ecs-task-execution` |
| IAM task role | `task-manager-prod-ecs-task` |
| ALB | `task-manager-prod-alb` (HTTP port 80) |
| Frontend target group | `task-manager-prod-frontend-tg` (port 80, health check `/`) |
| Backend target group | `task-manager-prod-backend-tg` (port 8000, health check `/api/health`) |
| ALB security group | `task-manager-prod-alb-sg` (inbound TCP 80 from `0.0.0.0/0`) |
| Frontend ECS security group | `task-manager-prod-frontend-ecs-sg` (inbound TCP 80 from ALB SG only) |
| Backend ECS security group | `task-manager-prod-backend-ecs-sg` (inbound TCP 8000 from ALB SG only) |
| Backend ECS service | `task-manager-prod-backend-service` |
| Frontend ECS service | `task-manager-prod-frontend-service` |
| Secrets Manager (MONGO_URI) | `task-manager-prod/mongo-uri` (container only — no value in Terraform) |
| Secrets Manager (SECRET_KEY) | `task-manager-prod/secret-key` (container only — no value in Terraform) |

### Networking design (cost-conscious)

**No NAT Gateway is created.** NAT Gateway costs ~$0.045/hour (~$32/month) plus data charges, which is significant for a personal practice project.

ECS Fargate tasks run in the **public subnets** with `assign_public_ip = true`. Security groups restrict all inbound container traffic to the ALB security group only, so containers are not directly reachable from the internet despite having public IPs. However, outbound traffic from ECS tasks (to MongoDB Atlas and AWS APIs) leaves from the task's public IP, which is not stable across task restarts — see the egress note in Step 5 below.

**This is acceptable for a practice deployment, but not the preferred hardened production architecture.** For a real production system, use private subnets + NAT Gateway (or VPC endpoints + Atlas PrivateLink) so containers never have public IPs and egress is predictable. This is documented in `networking.tf` as future work.

---

## Prerequisites

- Terraform >= 1.6.0
- AWS CLI configured with sufficient IAM permissions
- Remote state bootstrap completed (see `infra/bootstrap/README.md`)

---

## First Deployment Order

Because the Secrets Manager secret *containers* are created by Terraform, you cannot populate them before the first `terraform apply`. The correct approach is a two-pass deployment.

### Step 1 — Bootstrap remote state (once only)

```bash
cd infra/bootstrap
terraform init
terraform apply -var="state_bucket_name=<your-unique-bucket-name>"
```

Note the outputs: `state_bucket_name`, `lock_table_name`.

### Step 2 — Create backend.hcl

`infra/backend.hcl` is intentionally untracked (`.gitignore`) because it contains account-specific bucket details. Copy the example and fill in the bootstrap outputs:

```bash
cd infra
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl`:

```hcl
bucket         = "<state_bucket_name from bootstrap>"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "<lock_table_name from bootstrap>"
encrypt        = true
```

Do not commit `backend.hcl`.

### Step 3 — Initialise main infra

```bash
cd infra   # if not already there
terraform init -backend-config=backend.hcl
```

### Step 4 — Pass 1: apply with zero running tasks

Run the first apply with ECS desired counts at zero. This creates all AWS resources — ECR repos, ALB, target groups, ECS services, task definitions, IAM, log groups, and **Secrets Manager secret containers** — without attempting to start any ECS tasks. Tasks cannot start yet because images and secret values do not exist.

```bash
terraform apply \
  -var="backend_desired_count=0" \
  -var="frontend_desired_count=0"
```

### Step 5 — Populate secrets

The secret containers now exist. Populate them before Pass 2:

```bash
aws secretsmanager put-secret-value \
  --secret-id task-manager-prod/mongo-uri \
  --secret-string "mongodb+srv://<user>:<pass>@<cluster>.mongodb.net/?appName=<app>"

aws secretsmanager put-secret-value \
  --secret-id task-manager-prod/secret-key \
  --secret-string "<long-random-key>"
```

> **Note on egress and MongoDB Atlas:** Without a NAT Gateway, ECS tasks use their assigned public IPs for outbound traffic. These IPs are not stable — they change when tasks restart. For a practice deployment, the simplest option is to allow all IPs (`0.0.0.0/0`) in the Atlas Network Access list temporarily. For a stable production setup, use a NAT Gateway with an Elastic IP or Atlas PrivateLink so the egress IP is predictable.

### Step 6 — Build and push images to ECR

Use the git SHA as the image tag so ECR tag immutability is satisfied and the tag is traceable to a commit.

```bash
TAG=$(git rev-parse --short HEAD)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    "$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"

# Build and push backend
docker build -t task-manager-backend ./backend
docker tag task-manager-backend \
  "$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/task-manager-prod-backend:$TAG"
docker push \
  "$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/task-manager-prod-backend:$TAG"

# Build and push frontend
docker build -t task-manager-frontend ./frontend
docker tag task-manager-frontend \
  "$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/task-manager-prod-frontend:$TAG"
docker push \
  "$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/task-manager-prod-frontend:$TAG"
```

### Step 7 — Pass 2: apply with real image tags and desired counts

```bash
terraform apply \
  -var="backend_image_tag=$TAG" \
  -var="frontend_image_tag=$TAG" \
  -var="backend_desired_count=1" \
  -var="frontend_desired_count=1"
```

ECS will pull the images, inject the secrets, and start both tasks. The deployment circuit breaker will roll back automatically if health checks fail.

### Step 8 — Test

```bash
terraform output alb_url
# Expected output: http://<alb-dns-name>

# Check backend health
curl http://<alb_dns_name>/api/health
# Expected: {"status": "ok"}
```

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `project` | `task-manager` | Project name prefix |
| `environment` | `prod` | Environment name |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `public_subnet_cidrs` | `["10.0.1.0/24","10.0.2.0/24"]` | Public subnet CIDRs |
| `availability_zones` | `["us-east-1a","us-east-1b"]` | AZs for subnets |
| `log_retention_days` | `7` | CloudWatch log retention |
| `backend_image_tag` | `dev` | ECR tag for backend image |
| `frontend_image_tag` | `dev` | ECR tag for frontend image |
| `backend_desired_count` | `1` | Backend ECS task count |
| `frontend_desired_count` | `1` | Frontend ECS task count |
| `backend_cpu` | `256` | Backend CPU units |
| `backend_memory` | `512` | Backend memory (MiB) |
| `frontend_cpu` | `256` | Frontend CPU units |
| `frontend_memory` | `512` | Frontend memory (MiB) |
| `cors_origins` | `http://localhost` | CORS_ORIGINS env var for backend |

---

## Files

| File | Purpose |
|---|---|
| `providers.tf` | AWS provider and Terraform version requirements |
| `backend.tf` | Partial S3 backend block — real values supplied via `backend.hcl` at init time |
| `backend.hcl.example` | Committed template; copy to `backend.hcl` and fill in bootstrap outputs |
| `variables.tf` | Input variable declarations |
| `locals.tf` | Computed locals: name prefix, common tags |
| `networking.tf` | VPC, public subnets, Internet Gateway, route table |
| `ecr.tf` | ECR repositories for backend and frontend images |
| `ecs.tf` | ECS cluster |
| `iam.tf` | ECS task execution role, task role, and Secrets Manager read policy |
| `logs.tf` | CloudWatch log groups |
| `security_groups.tf` | ALB, frontend ECS, and backend ECS security groups |
| `secrets.tf` | Secrets Manager secret containers (values populated manually) |
| `alb.tf` | ALB, target groups, HTTP listener, and `/api/*` listener rule |
| `task_definitions.tf` | Backend and frontend Fargate task definitions |
| `services.tf` | Backend and frontend ECS services |
| `outputs.tf` | Exported values |

---

## What is NOT in this part

The following will be added in later deployment parts:

- HTTPS / ACM certificate
- Route 53 / DNS
- GitHub Actions CI/CD pipeline
- Private subnets + NAT Gateway (documented as future hardening)
