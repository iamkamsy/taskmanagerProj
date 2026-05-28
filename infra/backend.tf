# ---------------------------------------------------------------------------
# Partial S3 backend configuration.
#
# Real backend values (bucket, dynamodb_table) are account-specific and are
# supplied at init time via an untracked backend.hcl file:
#
#   terraform init -backend-config=backend.hcl
#
# To create backend.hcl:
#   1. Run infra/bootstrap to provision the S3 bucket and DynamoDB table.
#   2. Copy infra/backend.hcl.example to infra/backend.hcl.
#   3. Fill in the bootstrap outputs.
#
# backend.hcl is listed in .gitignore and must never be committed.
# backend.hcl.example is committed as the template.
# ---------------------------------------------------------------------------

terraform {
  backend "s3" {}
}
