# terraform-aws-static-website

Reusable Terraform module to deploy a static website on AWS with S3, CloudFront, optional ACM, optional Route 53 records, and optional WAF.

## Overview

This module provisions:
- S3 bucket for static website content
- CloudFront distribution with security headers and optional logging
- ACM certificate in `us-east-1` for HTTPS (optional)
- Route 53 DNS records in an existing hosted zone (optional)
- Optional WAF Web ACL
- Optional email-related DNS records
- Optional subdomain CloudFront aliases

> The module does **not** create a Route 53 hosted zone. Pass an existing `zone_id`.

> `www` is not created automatically. Add it explicitly via `subdomains`.

## Requirements

- Terraform `>= 1.0`
- AWS provider `~> 5.0`

## Providers

- `aws` (default) — regional resources
- `aws.us_east_1` — ACM certificate and WAF (must be us-east-1 for CloudFront)

## Example Usage

### Minimal — dev/staging

No custom domain, no ACM, no WAF. Uses the default CloudFront URL.

```hcl
module "static_website" {
  source = "./modules/terraform-aws-static-website"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name = "example.com"
  bucket_name = "example-com-website"
}
```

### Production — custom domain with ACM and WAF

```hcl
module "static_website" {
  source = "./modules/terraform-aws-static-website"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name = "example.com"
  bucket_name = "example-com-website"
  enable_acm  = true
  zone_id     = "Z08578232AQ4K9C2854A3"
  enable_waf  = true

  subdomains = ["www", "app"]
}
```

### Production — with central logging

```hcl
module "static_website" {
  source = "./modules/terraform-aws-static-website"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name = "example.com"
  bucket_name = "example-com-website"
  enable_acm  = true
  zone_id     = "Z08578232AQ4K9C2854A3"
  enable_waf  = true

  logging = {
    enabled            = true
    bucket_id          = module.central_logging.bucket_id
    bucket_arn         = module.central_logging.bucket_arn
    bucket_domain_name = module.central_logging.bucket_domain_name
  }
}
```

### Production — with email DNS records

```hcl
module "static_website" {
  source = "./modules/terraform-aws-static-website"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name           = "example.com"
  bucket_name           = "example-com-website"
  enable_acm            = true
  zone_id               = "Z08578232AQ4K9C2854A3"
  include_email_records = true

  email_records = {
    mx_record  = { priority = 10, value = "mail.example.com" }
    webmail_ip = "1.2.3.4"
    mail_ip    = "1.2.3.4"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `domain_name` | string | required | Primary website domain name |
| `bucket_name` | string | required | S3 bucket name for website hosting |
| `enable_acm` | bool | `false` | Create an ACM certificate and use a custom domain on CloudFront |
| `zone_id` | string | `null` | Existing Route 53 hosted zone ID. Required when `enable_acm = true` |
| `website_setup` | map(string) | `{ index_document = "index.html", error_document = "error.html" }` | Website root and error document names |
| `tags` | map(string) | `{}` | Tags to assign to AWS resources |
| `subdomains` | list(string) | `[]` | Subdomain names to create as CloudFront alias Route 53 records (e.g. `["www", "app"]`) |
| `include_email_records` | bool | `false` | Create email-related DNS records |
| `email_records` | object | `null` | Email DNS configuration (required if `include_email_records = true`) |
| `logging` | object | `{ enabled = false }` | Central logging bucket configuration |
| `content_security_policy` | string | `default-src 'self'; ...` | Content-Security-Policy header value |
| `enable_waf` | bool | `false` | Attach an AWS WAF Web ACL to CloudFront |

### `logging` object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | required | Enable S3, CloudFront, and WAF logging |
| `bucket_id` | string | `null` | Logging bucket name |
| `bucket_arn` | string | `null` | Logging bucket ARN (used for WAF logging) |
| `bucket_domain_name` | string | `null` | Logging bucket domain name (used for CloudFront logging) |
| `s3_prefix` | string | `s3-access-logs/` | S3 access log prefix |
| `cloudfront_prefix` | string | `cloudfront-access-logs/` | CloudFront log prefix |
| `waf_prefix` | string | `waf-logs/` | WAF log prefix |

### `email_records` object

| Field | Type | Description |
|-------|------|-------------|
| `mx_record.priority` | number | MX record priority |
| `mx_record.value` | string | Mail server hostname |
| `webmail_ip` | string | A record IP for `webmail.<domain>` |
| `mail_ip` | string | A record IP for `mail.<domain>` |

## Outputs

| Name | Description |
|------|-------------|
| `cloudfront_distribution_id` | CloudFront distribution ID |
| `cloudfront_distribution_arn` | CloudFront distribution ARN |
| `cloudfront_domain_name` | CloudFront distribution domain name |
| `website_url` | Website URL (`https://<domain>` when `enable_acm = true`, CloudFront URL otherwise) |
| `s3_bucket_name` | Website S3 bucket name |
| `s3_bucket_arn` | Website S3 bucket ARN |
| `route53_zone_id` | The `zone_id` passed in |
| `subdomain_fqdns` | Map of subdomain name to FQDN |

## Notes

- The module does not create a Route 53 hosted zone — pass an existing `zone_id`.
- `enable_acm = true` requires `zone_id` to be set for DNS certificate validation.
- Set `enable_acm = false` to use the default CloudFront certificate and URL (e.g. for dev/staging).
- WAF logging only activates when both `enable_waf = true` and `logging.enabled = true`.
