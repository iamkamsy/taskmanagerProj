output "state_bucket_name" {
  description = "S3 bucket name for Terraform state. Copy this into infra/backend.tf."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state S3 bucket."
  value       = aws_s3_bucket.tfstate.arn
}

output "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking. Copy this into infra/backend.tf."
  value       = aws_dynamodb_table.tflock.name
}

output "lock_table_arn" {
  description = "ARN of the DynamoDB lock table."
  value       = aws_dynamodb_table.tflock.arn
}

output "aws_region" {
  description = "AWS region where bootstrap resources were created."
  value       = var.aws_region
}
