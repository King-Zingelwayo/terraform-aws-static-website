locals {
  website_bucket = var.prevent_bucket_destroy ? aws_s3_bucket.website_bucket[0] : aws_s3_bucket.website_bucket_unprotected[0]
  log_bucket     = var.enable_log_bucket ? (var.prevent_bucket_destroy ? aws_s3_bucket.log_bucket[0] : aws_s3_bucket.log_bucket_unprotected[0]) : null
}