output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the main VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.main.arn
}

output "backend_ecr_repository_url" {
  description = "ECR repository URL for the backend image."
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "ECR repository URL for the frontend image."
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task IAM role."
  value       = aws_iam_role.ecs_task.arn
}

output "backend_log_group_name" {
  description = "CloudWatch log group name for the backend service."
  value       = aws_cloudwatch_log_group.backend.name
}

output "frontend_log_group_name" {
  description = "CloudWatch log group name for the frontend service."
  value       = aws_cloudwatch_log_group.frontend.name
}

# ---------------------------------------------------------------------------
# Part 3 outputs — ALB, services, target groups, secrets
# ---------------------------------------------------------------------------

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Full HTTP URL of the Application Load Balancer."
  value       = "http://${aws_lb.main.dns_name}"
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service."
  value       = aws_ecs_service.frontend.name
}

output "backend_service_name" {
  description = "Name of the backend ECS service."
  value       = aws_ecs_service.backend.name
}

output "frontend_target_group_arn" {
  description = "ARN of the frontend ALB target group."
  value       = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  description = "ARN of the backend ALB target group."
  value       = aws_lb_target_group.backend.arn
}

output "mongo_uri_secret_arn" {
  description = "ARN of the Secrets Manager secret for MONGO_URI."
  value       = aws_secretsmanager_secret.mongo_uri.arn
}

output "secret_key_secret_arn" {
  description = "ARN of the Secrets Manager secret for SECRET_KEY."
  value       = aws_secretsmanager_secret.secret_key.arn
}
