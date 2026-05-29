# ---------------------------------------------------------------------------
# Application Load Balancer — HTTP only (Part 3)
#
# HTTPS, ACM, and Route 53 are not configured here. They will be added in a
# later deployment part. All traffic currently travels over HTTP on port 80.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# ---------------------------------------------------------------------------
# Target groups
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "frontend" {
  name        = "${local.name_prefix}-frontend-tg"
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-frontend-tg"
  })
}

resource "aws_lb_target_group" "backend" {
  name        = "${local.name_prefix}-backend-tg"
  target_type = "ip"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/api/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backend-tg"
  })
}

# ---------------------------------------------------------------------------
# HTTP listener — port 80
# Default action: forward to frontend target group.
# /api/* rule: forward to backend target group.
# ---------------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
