# ---------------------------------------------------------------------------
# ECS task definitions — backend and frontend (Fargate, awsvpc)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Backend task definition
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name_prefix}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_cpu
  memory                   = var.backend_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:${var.backend_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      command = ["gunicorn", "app:app", "--bind", "0.0.0.0:8000"]

      environment = [
        { name = "DB_NAME", value = "taskmanager" },
        { name = "SESSION_COOKIE_SECURE", value = "false" },
        { name = "FLASK_DEBUG", value = "false" },
        { name = "TLS_INSECURE", value = "false" },
        { name = "CORS_ORIGINS", value = var.cors_origins }
      ]

      secrets = [
        {
          name      = "MONGO_URI"
          valueFrom = aws_secretsmanager_secret.mongo_uri.arn
        },
        {
          name      = "SECRET_KEY"
          valueFrom = aws_secretsmanager_secret.secret_key.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backend-td"
  })
}

# ---------------------------------------------------------------------------
# Frontend task definition
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${local.name_prefix}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.frontend_cpu
  memory                   = var.frontend_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:${var.frontend_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-frontend-td"
  })
}
