output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website_distribution.id
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website_distribution.arn
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website_distribution.domain_name
}

output "website_url" {
  description = "The live website URL"
  value       = var.enable_acm ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.website_distribution.domain_name}"
}

output "s3_bucket_name" {
  description = "The name of the website S3 bucket"
  value       = local.website_bucket.bucket
}

output "s3_bucket_arn" {
  description = "The ARN of the website S3 bucket"
  value       = local.website_bucket.arn
}

output "route53_zone_id" {
  description = "The Route 53 hosted zone ID"
  value       = var.zone_id
}

output "subdomain_fqdns" {
  description = "FQDNs of all created subdomains"
  value       = { for k, v in aws_route53_record.subdomain_cloudfront : k => v.fqdn }
}

output "api_origin_secret_arns" {
  description = "SSM Parameter ARNs for each API origin secret — reference these in your API Gateway resource policy"
  value       = { for k, v in aws_ssm_parameter.origin_secret : k => v.arn }
}
