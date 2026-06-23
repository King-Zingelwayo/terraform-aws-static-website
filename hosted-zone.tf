# Route 53 A + AAAA alias records pointing to CloudFront
resource "aws_route53_record" "website_alias" {
  for_each = var.enable_acm ? toset(["A", "AAAA"]) : toset([])
  zone_id  = var.zone_id
  name     = var.domain_name
  type     = each.key

  alias {
    name                   = local.cf_domain_name
    zone_id                = local.cf_zone_id
    evaluate_target_health = false
  }
}

# Route 53 records for ACM certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_acm ? {
    for dvo in aws_acm_certificate.website_cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}

# ACM certificate validation
resource "aws_acm_certificate_validation" "website_cert_validation" {
  count                   = var.enable_acm ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.website_cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  depends_on = [aws_route53_record.cert_validation]
}

# Email DNS records (MX, webmail A, mail A)
resource "aws_route53_record" "email_records" {
  for_each = local.email_records
  zone_id  = var.zone_id
  name     = each.value.name
  type     = each.value.type
  ttl      = 14401
  records  = each.value.records
}

resource "aws_route53_record" "subdomain_cloudfront" {
  for_each = local.subdomain_cloudfront
  zone_id  = var.zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"

  alias {
    name                   = local.cf_domain_name
    zone_id                = local.cf_zone_id
    evaluate_target_health = false
  }
}
