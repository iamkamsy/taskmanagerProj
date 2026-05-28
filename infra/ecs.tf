# ---------------------------------------------------------------------------
# ECS cluster — foundation only
#
# No ECS services, task definitions, or ALB are created in this part.
# Those will be added in a later deployment part.
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled" # Enable in production for observability; disabled here to limit cost.
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster"
  })
}
