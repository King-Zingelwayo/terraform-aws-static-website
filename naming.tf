# Plan-time locals — derived purely from variables, always known during plan
locals {
  website_bucket  = aws_s3_bucket.website_bucket
  logging_enabled = var.logging.enabled

  subdomain_cloudfront = var.enable_acm ? { for s in var.subdomains : s => s } : {}
}

# Apply-time locals — reference resource attributes known only after apply
locals {
  cf_domain_name = aws_cloudfront_distribution.website_distribution.domain_name
  cf_zone_id     = aws_cloudfront_distribution.website_distribution.hosted_zone_id

  email_records = var.email_records != null ? {
    mx      = { name = var.domain_name, type = "MX", records = ["${var.email_records.mx_record.priority} ${var.email_records.mx_record.value}"] }
    webmail = { name = "webmail.${var.domain_name}", type = "A", records = [var.email_records.webmail_ip] }
    mail    = { name = "mail.${var.domain_name}", type = "A", records = [var.email_records.mail_ip] }
  } : {}
}
