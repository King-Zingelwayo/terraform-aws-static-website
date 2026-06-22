# Generate a random secret per API origin
resource "random_password" "origin_secret" {
  for_each = { for o in var.api_origins : o.origin_id => o }

  length  = 32
  special = false
}

# Store each secret in SSM Parameter Store (Standard tier, free)
resource "aws_ssm_parameter" "origin_secret" {
  for_each = { for o in var.api_origins : o.origin_id => o }

  name        = "/cloudfront/${each.key}/origin-secret"
  type        = "SecureString"
  value       = random_password.origin_secret[each.key].result
  description = "CloudFront origin secret for ${each.key}"
  tags        = var.tags
}
