# Terraform Bootstrap

Creates the S3 bucket and DynamoDB table that the main `infra/` module uses for remote state storage and locking. Run this **once** before initialising the main infrastructure.

> **Note:** Bootstrap itself uses local state. Do not store bootstrap state in the bucket it creates.

---

## Prerequisites

- AWS CLI configured (`aws configure` or environment variables)
- Terraform >= 1.6.0
- IAM permissions: S3 bucket create/configure, DynamoDB table create

---

## S3 Bucket Naming

S3 bucket names are **globally unique** across all AWS accounts. The default name `task-manager-prod-tfstate` may already be taken. Override it:

```bash
terraform apply -var="state_bucket_name=your-unique-bucket-name-here"
```

Choose something unique, for example by appending your AWS account ID:

```bash
terraform apply -var="state_bucket_name=task-manager-prod-tfstate-123456789012"
```

---

## Steps

### 1. Initialise (local state only)

```bash
cd infra/bootstrap
terraform init
```

### 2. Plan

```bash
terraform plan -var="state_bucket_name=<your-unique-bucket-name>"
```

Review the plan — it will create one S3 bucket and one DynamoDB table.

### 3. Apply

```bash
terraform apply -var="state_bucket_name=<your-unique-bucket-name>"
```

Type `yes` when prompted. Note the outputs:

```
state_bucket_name = "your-unique-bucket-name"
lock_table_name   = "task-manager-prod-tflock"
aws_region        = "us-east-1"
```

### 4. Create infra/backend.hcl from the example

`infra/backend.hcl` is intentionally untracked because it contains account-specific bucket details. Copy the committed example and fill in the bootstrap outputs:

```bash
cd ..   # infra/
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` with the outputs from step 3:

```hcl
bucket         = "<state_bucket_name output>"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "<lock_table_name output>"
encrypt        = true
```

Do not commit `backend.hcl`.

### 5. Initialise the main infra with remote backend

```bash
# From infra/
terraform init -backend-config=backend.hcl
```

Terraform will prompt to migrate any existing local state into the S3 bucket.

---

## Resources Created

| Resource | Name |
|---|---|
| S3 bucket | `<state_bucket_name variable>` |
| DynamoDB table | `task-manager-prod-tflock` |

Both have `prevent_destroy = true` on the S3 bucket to guard against accidental deletion.

---

## Tearing Down

To destroy the bootstrap resources you must first remove `prevent_destroy = true` from `main.tf`, then run `terraform destroy`. Only do this after all other infrastructure using this state backend has been destroyed.
