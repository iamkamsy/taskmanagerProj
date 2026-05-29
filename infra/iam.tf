# ---------------------------------------------------------------------------
# IAM — ECS task execution role and task role
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ECS task execution role
# Used by the ECS agent to pull images from ECR and write logs to CloudWatch.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name_prefix}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-task-execution"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# ECS task role
# The role assumed by the running application container itself.
# No inline permissions are attached yet. Secrets Manager and other
# app-level permissions will be added in a later part.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-task"
  })
}

# ---------------------------------------------------------------------------
# Secrets Manager read permission for the task execution role
#
# The ECS agent (execution role) must call GetSecretValue to inject the
# MONGO_URI and SECRET_KEY secrets into the container environment.
# Permission is scoped to exactly the two secret ARNs — no wildcard.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "secrets_read" {
  statement {
    sid     = "ReadAppSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.mongo_uri.arn,
      aws_secretsmanager_secret.secret_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name   = "${local.name_prefix}-secrets-read"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.secrets_read.json
}
