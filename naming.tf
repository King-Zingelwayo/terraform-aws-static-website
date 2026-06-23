locals {
  website_bucket = var.prevent_bucket_destroy ? aws_s3_bucket.website_bucket[0] : aws_s3_bucket.website_bucket_unprotected[0]
  log_bucket     = var.enable_log_bucket ? (var.prevent_bucket_destroy ? aws_s3_bucket.log_bucket[0] : aws_s3_bucket.log_bucket_unprotected[0]) : null


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