resource "aws_acm_certificate" "website_cert" {
  count    = var.deploy_to_prod ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = [for s in var.subdomains : "${s.name}.${var.domain_name}" if s.target_type == "cloudfront"]
  validation_method = "DNS"

  tags = merge(var.tags, { Name = var.domain_name })

  lifecycle {
    create_before_destroy = true
  }
}
