locals {
  # Shared name prefix used consistently across all resources.
  name_prefix = "${var.project}-${var.environment}"

  # Common tags applied to all resources.
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
