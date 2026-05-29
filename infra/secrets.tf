# ---------------------------------------------------------------------------
# Secrets Manager — placeholder secrets for app credentials
#
# These resources create secret *containers* only. No secret values are
# stored in Terraform or in source control.
#
# First run the initial `terraform apply` with ECS desired counts set to 0 so
# Terraform creates these secret containers without starting tasks. Then
# populate each secret manually via the AWS Console or CLI before the second
# apply that starts ECS tasks:
#
#   aws secretsmanager put-secret-value \
#     --secret-id <mongo-secret-name-or-arn> \
#     --secret-string "<your-mongodb-atlas-uri>"
#
#   aws secretsmanager put-secret-value \
#     --secret-id <secret-key-name-or-arn> \
#     --secret-string "<long-random-string>"
#
# ECS task containers will fail to start if these secrets are not populated
# before the services are deployed.
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "mongo_uri" {
  name        = "${local.name_prefix}/mongo-uri"
  description = "MongoDB Atlas connection URI for the task manager backend."

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}/mongo-uri"
  })
}

resource "aws_secretsmanager_secret" "secret_key" {
  name        = "${local.name_prefix}/secret-key"
  description = "Flask SECRET_KEY used to sign session cookies."

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}/secret-key"
  })
}
