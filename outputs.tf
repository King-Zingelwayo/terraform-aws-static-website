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
  value       = var.deploy_to_prod ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.website_distribution.domain_name}"
}

output "s3_bucket_name" {
  description = "The name of the website S3 bucket"
  value       = aws_s3_bucket.website_bucket.bucket
}

output "s3_bucket_arn" {
  description = "The ARN of the website S3 bucket"
  value       = aws_s3_bucket.website_bucket.arn
}

output "s3_log_bucket_name" {
  description = "The name of the access log S3 bucket"
  value       = var.enable_log_bucket ? aws_s3_bucket.log_bucket[0].bucket : null
}

output "route53_zone_id" {
  description = "The Route 53 hosted zone ID (set when deploy_hosted_zone or deploy_to_prod is true)"
  value       = local.zone_id
}

output "route53_nameservers" {
  description = "Nameservers for the Route 53 hosted zone — use these to delegate the domain at your registrar"
  value       = local.create_zone ? aws_route53_zone.website_zone[0].name_servers : []
}

output "subdomain_fqdns" {
  description = "FQDNs of all created subdomains"
  value = merge(
    { for k, v in aws_route53_record.subdomain_cloudfront : k => v.fqdn },
    { for k, v in aws_route53_record.subdomain_alb : k => v.fqdn },
    { for k, v in aws_route53_record.subdomain_a : k => v.fqdn }
  )
}
