variable "aws_region" {
  description = "AWS region to create bootstrap resources in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used in resource naming."
  type        = string
  default     = "task-manager"
}

variable "environment" {
  description = "Environment name, used in resource naming."
  type        = string
  default     = "prod"
}

variable "state_bucket_name" {
  description = <<-EOT
    Globally unique S3 bucket name for Terraform state storage.
    S3 bucket names must be globally unique across all AWS accounts.
    The default is a prefix — change it to something unique before running apply.
  EOT
  type        = string
  default     = "task-manager-prod-tfstate"
}
