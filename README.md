# terraform-aws-static-website

Reusable Terraform module to deploy a static website on AWS with S3, CloudFront, ACM, Route 53, and optional WAF.

## Overview

This module provisions:
- S3 bucket for static website content with HTTPS-only bucket policy
- CloudFront distribution with security headers
- ACM certificate in `us-east-1` for HTTPS (optional)
- Route 53 DNS records (optional, requires an existing hosted zone)
- Optional WAF Web ACL
- Optional API Gateway origins
- Optional email DNS records
- Optional subdomain CloudFront aliases

> The module does **not** create a Route 53 hosted zone or logging bucket — these must be provisioned externally and passed in.

## Requirements

- Terraform `>= 1.0`
- AWS provider `~> 5.0`

## Providers

- `aws` (default) — regional resources
- `aws.us_east_1` — ACM certificate and WAF (must be us-east-1 for CloudFront)

## Example Usage

### Minimal — no custom domain

No ACM, no WAF. Uses the default CloudFront URL.

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

### With ACM and custom domain

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

### With central logging

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
    s3_prefix          = "s3-access-logs/"
    cloudfront_prefix  = "cloudfront-access-logs/"
    waf_prefix         = "waf-logs/"
  }
}
```

### With API Gateway origin

Routes `/api/*` to API Gateway, everything else to S3.

```hcl
module "static_website" {
  source = "./modules/terraform-aws-static-website"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name = "app.example.com"
  bucket_name = "example-com-website"
  enable_acm  = true
  zone_id     = "Z08578232AQ4K9C2854A3"

  api_origins = [
    {
      origin_id       = "main-api"
      api_gateway_url = "https://abc123.execute-api.eu-west-1.amazonaws.com/prod"
      path_patterns   = ["/api/*"]
    }
  ]
}
```

### With email DNS records

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
| `bucket_name` | string | required | S3 bucket name for website content |
| `enable_acm` | bool | `false` | Enable ACM certificate and HTTPS for CloudFront |
| `zone_id` | string | `null` | Existing Route 53 hosted zone ID. Required when `enable_acm = true` |
| `subdomains` | list(string) | `[]` | Subdomain names to add as CloudFront aliases and Route 53 records (e.g. `["www", "app"]`) |
| `website_setup` | map(string) | `{ index_document = "index.html", error_document = "error.html" }` | Root and error document names |
| `tags` | map(string) | `{}` | Tags to assign to all resources |
| `content_security_policy` | string | `default-src 'self'; ...` | Content-Security-Policy header value |
| `enable_waf` | bool | `false` | Attach an AWS WAF Web ACL to CloudFront |
| `logging` | object | `{ enabled = false }` | Central logging bucket configuration (see below) |
| `api_origins` | list(object) | `[]` | API Gateway origins to attach to CloudFront (see below) |
| `include_email_records` | bool | `false` | Create email-related DNS records |
| `email_records` | object | `null` | Email DNS configuration. Required when `include_email_records = true` |

### `logging` object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | required | Enable logging |
| `bucket_id` | string | `null` | Bucket name/ID for S3 access logging |
| `bucket_arn` | string | `null` | Bucket ARN for WAF logging |
| `bucket_domain_name` | string | `null` | Bucket domain name for CloudFront logging |
| `s3_prefix` | string | `s3-access-logs/` | S3 access log prefix |
| `cloudfront_prefix` | string | `cloudfront-access-logs/` | CloudFront log prefix |
| `waf_prefix` | string | `waf-logs/` | WAF log prefix |

### `api_origins` object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `origin_id` | string | required | Unique identifier for the origin |
| `api_gateway_url` | string | required | Full HTTPS URL of the API Gateway stage |
| `path_patterns` | list(string) | required | CloudFront path patterns to route to this origin |
| `allowed_methods` | list(string) | all methods | HTTP methods to allow |

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
| `website_url` | Website URL (`https://<domain>` when `enable_acm = true`) |
| `s3_bucket_name` | Website S3 bucket name |
| `s3_bucket_arn` | Website S3 bucket ARN |
| `route53_zone_id` | The zone ID passed in |
| `subdomain_fqdns` | Map of subdomain name to FQDN |
| `api_origin_secret_arns` | Map of SSM Parameter ARNs for each API origin secret |

## Notes

- The module does not create a Route 53 hosted zone — pass an existing `zone_id`.
- The module does not create a logging bucket — pass an external bucket via `logging`.
- `enable_acm = true` requires `zone_id` to be set for DNS certificate validation.
- API Gateway origins are secured with a per-origin secret stored in SSM at `/cloudfront/<origin_id>/origin-secret`. Reference `api_origin_secret_arns` in your API Gateway resource policy to restrict access to CloudFront only.
- WAF logging only activates when both `enable_waf = true` and `logging.enabled = true`.
- `www.<domain>` is not created automatically — add `"www"` to `subdomains` explicitly.
