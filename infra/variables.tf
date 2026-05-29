variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name prefix used in resource naming."
  type        = string
  default     = "task-manager"
}

variable "environment" {
  description = "Environment name used in resource naming."
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for the public subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days. Short retention limits cost."
  type        = number
  default     = 7
}

# ---------------------------------------------------------------------------
# Part 3 — image tags, desired counts, cpu/memory, CORS
# ---------------------------------------------------------------------------

variable "backend_image_tag" {
  description = "ECR image tag to deploy for the backend container."
  type        = string
  default     = "dev"
}

variable "frontend_image_tag" {
  description = "ECR image tag to deploy for the frontend container."
  type        = string
  default     = "dev"
}

variable "backend_desired_count" {
  description = "Number of backend ECS tasks to run."
  type        = number
  default     = 1
}

variable "frontend_desired_count" {
  description = "Number of frontend ECS tasks to run."
  type        = number
  default     = 1
}

variable "backend_cpu" {
  description = "CPU units for the backend Fargate task (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "backend_memory" {
  description = "Memory in MiB for the backend Fargate task."
  type        = number
  default     = 512
}

variable "frontend_cpu" {
  description = "CPU units for the frontend Fargate task (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Memory in MiB for the frontend Fargate task."
  type        = number
  default     = 512
}

variable "cors_origins" {
  description = "Allowed CORS origin(s) passed to the backend container as CORS_ORIGINS."
  type        = string
  default     = "http://localhost"
}
