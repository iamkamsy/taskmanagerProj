# ---------------------------------------------------------------------------
# Security groups — ALB and ECS tasks
#
# ALB SG:       accepts inbound HTTP from the internet on port 80.
# Frontend SG:  accepts inbound on port 80 only from the ALB SG.
# Backend SG:   accepts inbound on port 8000 only from the ALB SG.
#
# ECS tasks are never directly reachable from the public internet despite
# running in public subnets with assign_public_ip = true.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ALB security group
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow HTTP inbound to ALB from the internet."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

# ---------------------------------------------------------------------------
# Frontend ECS security group
# ---------------------------------------------------------------------------

resource "aws_security_group" "frontend_ecs" {
  name        = "${local.name_prefix}-frontend-ecs-sg"
  description = "Allow inbound on port 80 from ALB only."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-frontend-ecs-sg"
  })
}

# ---------------------------------------------------------------------------
# Backend ECS security group
# ---------------------------------------------------------------------------

resource "aws_security_group" "backend_ecs" {
  name        = "${local.name_prefix}-backend-ecs-sg"
  description = "Allow inbound on port 8000 from ALB only."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Gunicorn from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backend-ecs-sg"
  })
}
