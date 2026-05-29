# ---------------------------------------------------------------------------
# ECS services — backend and frontend (Fargate, public subnets)
#
# Both services run in public subnets with assign_public_ip = true because
# no NAT Gateway is provisioned. Security groups restrict all inbound
# container traffic to the ALB security group — containers are not
# reachable directly from the internet.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Backend ECS service
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "backend" {
  name            = "${local.name_prefix}-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.backend_ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backend-service"
  })
}

# ---------------------------------------------------------------------------
# Frontend ECS service
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "frontend" {
  name            = "${local.name_prefix}-frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.frontend_ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-frontend-service"
  })
}
