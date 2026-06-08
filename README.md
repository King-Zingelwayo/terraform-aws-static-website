# terraform-aws-static-website

Reusable Terraform module to deploy a static website on AWS with S3, CloudFront, ACM, Route 53, optional WAF, and DNS management.

## Overview

This module provisions:
- S3 bucket for static website content
- CloudFront distribution with security headers and optional logging
- ACM certificate in `us-east-1` for HTTPS
- Route 53 hosted zone and DNS records
- Optional WAF Web ACL
- Optional DNSSEC support
- Optional email-related DNS records
- Optional additional subdomains for CloudFront, ALB, or A records

> `www` is not created automatically. If you want `www.example.com`, add it explicitly in `subdomains`.

## Requirements

- Terraform `>= 1.0`
- AWS provider `~> 5.0`

## Providers

- `aws` (default) for regional resources
- `aws.us_east_1` for ACM and DNSSEC KMS key creation

## Example Usage

```hcl
module "static_website" {
  source = "./modules/terraform-aws-static-website"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  region             = "eu-west-1"
  deploy_to_prod     = true
  deploy_hosted_zone = true
  domain_name        = "example.com"
  bucket_name        = "example-com-website"
  enable_waf         = true

  subdomains = [
    {
      name        = "www"
      target_type = "cloudfront"
    }
  ]
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `eu-west-1` | AWS region for default provider resources |
| `deploy_to_prod` | bool | `false` | Deploy CloudFront, ACM, and Route 53 records for production |
| `deploy_hosted_zone` | bool | `false` | Create a Route 53 hosted zone for the domain |
| `domain_name` | string | n/a | Primary website domain name |
| `bucket_name` | string | n/a | S3 bucket name for website hosting |
| `website_oac_name` | any | `null` | Deprecated; ignored |
| `website_setup` | map(string) | `{ index_document = "index.html", error_document = "error.html" }` | Website root and error document names |
| `tags` | map(string) | `{}` | Tags to assign to AWS resources |
| `existing_zone_id` | string | `null` | Use an existing Route 53 hosted zone instead of creating a new one |
| `subdomains` | list(object) | `[]` | Optional subdomain configuration for CloudFront, ALB, or A records |
| `include_email_records` | bool | `false` | Create email-related DNS records |
| `email_records` | object | `null` | Email DNS configuration (required if `include_email_records` is true) |
| `log_retention_days` | number | `90` | S3 and CloudFront log retention days |
| `enable_log_bucket` | bool | `true` | Create an S3 logging bucket for S3 and CloudFront access logs |
| `log_bucket_prevent_destroy` | bool | `true` | Protect the log and website S3 buckets from accidental destruction |
| `content_security_policy` | string | `default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'; object-src 'none'` | Content Security Policy header value |
| `enable_dnssec` | bool | `false` | Enable DNSSEC on the hosted zone |
| `dnssec_kms_key_arn` | string | `null` | Existing KMS key ARN for DNSSEC signing |
| `enable_waf` | bool | `false` | Attach an AWS WAF Web ACL to CloudFront |

### Subdomain object schema

- `name` - subdomain label (e.g. `www`, `app`, `api`)
- `target_type` - `cloudfront`, `alb`, or `a_record`
- `alb_dns_name` - required when `target_type = "alb"`
- `alb_zone_id` - required when `target_type = "alb"`
- `a_record_ips` - required when `target_type = "a_record"`

## Outputs

| Name | Description |
|------|-------------|
| `cloudfront_distribution_id` | CloudFront distribution ID |
| `cloudfront_distribution_arn` | CloudFront distribution ARN |
| `cloudfront_domain_name` | CloudFront distribution domain name |
| `website_url` | Website URL (`https://<domain>` in prod) |
| `s3_bucket_name` | Website S3 bucket name |
| `s3_bucket_arn` | Website S3 bucket ARN |
| `s3_log_bucket_name` | Access log S3 bucket name |
| `route53_zone_id` | Route 53 hosted zone ID |
| `route53_nameservers` | Hosted zone nameservers (when created) |
| `subdomain_fqdns` | FQDNs of created subdomains |

## Notes

- `www.${var.domain_name}` is not provisioned unless added via `subdomains`.
- Set `deploy_to_prod = true` to enable HTTPS and custom domain support.
- Use `existing_zone_id` with `deploy_hosted_zone = false` if you already manage the domain in Route 53.
- `enable_log_bucket = false` disables the log bucket, S3 access logging, and CloudFront logging entirely.
- `log_bucket_prevent_destroy = false` allows Terraform to destroy both the log and website buckets (use with caution).
