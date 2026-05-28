# Task Manager — Infrastructure (Part 2: Terraform Foundation)

Terraform configuration for the Task Manager production infrastructure on AWS.

- **Region:** `us-east-1`
- **Environment:** `prod`

> **Cost warning:** AWS resources created here may incur charges even without a NAT Gateway. ECR, ECS cluster, CloudWatch log storage, S3 state bucket, and DynamoDB lock table all have cost components. Review [AWS pricing](https://aws.amazon.com/pricing/) and monitor your billing dashboard.

---

## Architecture — Part 2 scope

This part creates the **foundation only**. No ECS services, task definitions, ALB, HTTPS, or secrets wiring yet.

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

### Networking design (cost-conscious)

**No NAT Gateway is created.** NAT Gateway costs ~$0.045/hour (~$32/month) plus data charges, which is significant for a personal practice project.

In a later part, ECS Fargate tasks will run in the **public subnets** with `assign_public_ip = true`. Security groups will restrict inbound container traffic to the ALB security group only, so containers are not directly reachable from the internet despite having public IPs.

**This is acceptable for a practice deployment, but not the preferred hardened production architecture.** For a real production system, use private subnets + NAT Gateway (or VPC endpoints + Atlas PrivateLink) so containers never have public IPs. This is documented in `networking.tf` as future work.

---

## Prerequisites

- Terraform >= 1.6.0
- AWS CLI configured with sufficient IAM permissions
- Remote state bootstrap completed (see `infra/bootstrap/README.md`)

---

## Setup

### Step 1 — Run bootstrap (once only)

```bash
cd infra/bootstrap
terraform init
terraform apply -var="state_bucket_name=<your-unique-bucket-name>"
```

Note the outputs: `state_bucket_name`, `lock_table_name`.

### Step 2 — Create backend.hcl

`infra/backend.hcl` is intentionally untracked (listed in `.gitignore`) because it contains account-specific bucket details. Copy the example and fill in the bootstrap outputs:

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

Do not commit `backend.hcl`. The committed `backend.hcl.example` is the template.

### Step 3 — Initialise with backend config

```bash
cd infra   # if not already there
terraform init -backend-config=backend.hcl
```

### Step 4 — Plan

```bash
terraform plan
```

Review the plan before applying. Confirm no unexpected resources appear.

### Step 5 — Apply

```bash
terraform apply
```

Type `yes` when prompted.

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
| `ecs.tf` | ECS cluster (no services or task definitions yet) |
| `iam.tf` | ECS task execution role and task role |
| `logs.tf` | CloudWatch log groups |
| `outputs.tf` | Exported values for use in later parts |

---

## What is NOT in this part

The following will be added in later deployment parts:

- ECS services and task definitions
- Application Load Balancer, target groups, listener rules
- HTTPS / ACM certificate
- Route 53 / DNS
- Secrets Manager for app secrets (MONGO_URI, SECRET_KEY)
- GitHub Actions CI/CD pipeline
- Private subnets (documented as future hardening)
