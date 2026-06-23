resource "aws_acm_certificate" "website_cert" {
  count    = var.enable_acm ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = [for s in var.subdomains : "${s}.${var.domain_name}"]
  validation_method         = "DNS"

  tags = merge(var.tags, { Name = var.domain_name })

  lifecycle {
    create_before_destroy = true
  }

}
