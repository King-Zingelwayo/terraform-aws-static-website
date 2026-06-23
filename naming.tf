# Plan-time locals — derived purely from variables, always known during plan
locals {
  website_bucket = var.prevent_bucket_destroy ? aws_s3_bucket.website_bucket[0] : aws_s3_bucket.website_bucket_unprotected[0]
  log_bucket     = var.enable_log_bucket ? (var.prevent_bucket_destroy ? aws_s3_bucket.log_bucket[0] : aws_s3_bucket.log_bucket_unprotected[0]) : null

  create_zone   = (var.deploy_to_prod || var.deploy_hosted_zone) && var.existing_zone_id == null
  use_zone      = var.deploy_to_prod || var.deploy_hosted_zone || var.existing_zone_id != null
  create_email  = local.use_zone && var.include_email_records
  create_dnssec = local.create_zone && var.enable_dnssec

  subdomain_cloudfront = {
    for s in var.subdomains : s.name => s if s.target_type == "cloudfront" && local.use_zone
  }
  subdomain_alb = {
    for s in var.subdomains : s.name => s if s.target_type == "alb" && local.use_zone
  }
  subdomain_a = {
    for s in var.subdomains : s.name => s if s.target_type == "a_record" && local.use_zone
  }
}

# Apply-time locals — reference resource attributes known only after apply
locals {
  zone_id        = var.existing_zone_id != null ? var.existing_zone_id : (local.create_zone ? aws_route53_zone.website_zone[0].zone_id : null)
  cf_domain_name = aws_cloudfront_distribution.website_distribution.domain_name
  cf_zone_id     = aws_cloudfront_distribution.website_distribution.hosted_zone_id
  kms_key_arn    = local.create_dnssec ? (var.dnssec_kms_key_arn != null ? var.dnssec_kms_key_arn : aws_kms_key.dnssec[0].arn) : null

  email_records = local.create_email ? {
    mx      = { name = var.domain_name, type = "MX", records = ["${var.email_records.mx_record.priority} ${var.email_records.mx_record.value}"] }
    webmail = { name = "webmail.${var.domain_name}", type = "A", records = [var.email_records.webmail_ip] }
    mail    = { name = "mail.${var.domain_name}", type = "A", records = [var.email_records.mail_ip] }
  } : {}
}
