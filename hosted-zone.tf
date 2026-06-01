locals {
  create_zone    = (var.deploy_to_prod || var.deploy_hosted_zone) && var.existing_zone_id == null
  use_zone       = var.deploy_to_prod || var.deploy_hosted_zone || var.existing_zone_id != null
  create_email   = local.use_zone && var.include_email_records
  zone_id        = var.existing_zone_id != null ? var.existing_zone_id : (local.create_zone ? aws_route53_zone.website_zone[0].zone_id : null)
  cf_domain_name = aws_cloudfront_distribution.website_distribution.domain_name
  cf_zone_id     = aws_cloudfront_distribution.website_distribution.hosted_zone_id
  create_dnssec  = local.create_zone && var.enable_dnssec
  kms_key_arn    = local.create_dnssec ? (var.dnssec_kms_key_arn != null ? var.dnssec_kms_key_arn : aws_kms_key.dnssec[0].arn) : null

  email_records = local.create_email ? {
    mx      = { name = var.domain_name, type = "MX", records = ["${var.email_records.mx_record.priority} ${var.email_records.mx_record.value}"] }
    webmail = { name = "webmail.${var.domain_name}", type = "A", records = [var.email_records.webmail_ip] }
    mail    = { name = "mail.${var.domain_name}", type = "A", records = [var.email_records.mail_ip] }
  } : {}
}

# Route 53 Hosted Zone
resource "aws_route53_zone" "website_zone" {
  count = local.create_zone ? 1 : 0
  name  = var.domain_name
  tags  = merge(var.tags, { Name = var.domain_name })

  lifecycle {
    prevent_destroy = true
  }
}

# Auto-created KMS key for DNSSEC when none is supplied
resource "aws_kms_key" "dnssec" {
  count                    = local.create_dnssec && var.dnssec_kms_key_arn == null ? 1 : 0
  provider                 = aws.us_east_1
  description              = "DNSSEC signing key for ${var.domain_name}"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowRoute53DNSSECService"
        Effect    = "Allow"
        Principal = { Service = "dnssec-route53.amazonaws.com" }
        Action    = ["kms:DescribeKey", "kms:GetPublicKey", "kms:Sign"]
        Resource  = "*"
      },
      {
        Sid       = "AllowAccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.domain_name}-dnssec-kms" })
}

resource "aws_kms_alias" "dnssec" {
  count         = local.create_dnssec && var.dnssec_kms_key_arn == null ? 1 : 0
  provider      = aws.us_east_1
  name          = "alias/${replace(var.domain_name, ".", "-")}-dnssec"
  target_key_id = aws_kms_key.dnssec[0].key_id
}

# DNSSEC signing key
resource "aws_route53_key_signing_key" "website_ksk" {
  count                      = local.create_dnssec ? 1 : 0
  hosted_zone_id             = aws_route53_zone.website_zone[0].id
  key_management_service_arn = local.kms_key_arn
  name                       = "${replace(var.domain_name, ".", "-")}-ksk"
}

resource "aws_route53_hosted_zone_dnssec" "website_dnssec" {
  count          = local.create_dnssec ? 1 : 0
  hosted_zone_id = aws_route53_zone.website_zone[0].id

  depends_on = [aws_route53_key_signing_key.website_ksk]
}

# Route 53 A + AAAA alias records pointing to CloudFront
resource "aws_route53_record" "website_alias" {
  for_each = var.deploy_to_prod ? toset(["A", "AAAA"]) : toset([])
  zone_id  = local.zone_id
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
  for_each = var.deploy_to_prod ? {
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
  zone_id         = local.zone_id
}

# ACM certificate validation
resource "aws_acm_certificate_validation" "website_cert_validation" {
  count                   = var.deploy_to_prod ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.website_cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Email DNS records (MX, webmail A, mail A)
resource "aws_route53_record" "email_records" {
  for_each = local.email_records
  zone_id  = local.zone_id
  name     = each.value.name
  type     = each.value.type
  ttl      = 14401
  records  = each.value.records
}

# Optional subdomain records — CloudFront alias, ALB alias, or plain A record
locals {
  subdomain_cloudfront = local.use_zone ? {
    for s in var.subdomains : s.name => s if s.target_type == "cloudfront"
  } : {}

  subdomain_alb = local.use_zone ? {
    for s in var.subdomains : s.name => s if s.target_type == "alb"
  } : {}

  subdomain_a = local.use_zone ? {
    for s in var.subdomains : s.name => s if s.target_type == "a_record"
  } : {}
}

resource "aws_route53_record" "subdomain_cloudfront" {
  for_each = local.subdomain_cloudfront
  zone_id  = local.zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"

  alias {
    name                   = local.cf_domain_name
    zone_id                = local.cf_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "subdomain_alb" {
  for_each = local.subdomain_alb
  zone_id  = local.zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"

  alias {
    name                   = each.value.alb_dns_name
    zone_id                = each.value.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "subdomain_a" {
  for_each = local.subdomain_a
  zone_id  = local.zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"
  ttl      = 300
  records  = each.value.a_record_ips
}
