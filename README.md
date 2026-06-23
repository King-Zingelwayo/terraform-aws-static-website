# terraform-aws-static-website

Reusable Terraform module to deploy a static website on AWS with S3, CloudFront, ACM, Route 53, optional WAF, and optional API Gateway origins.

## Overview

This module provisions:
- S3 bucket for static website content
- CloudFront distribution with security headers and optional logging
- ACM certificate in `us-east-1` for HTTPS
- Route 53 hosted zone and DNS records
- Optional WAF Web ACL
- Optional API Gateway origins with per-origin secret enforcement
- Optional DNSSEC support
- Optional email-related DNS records
- Optional subdomains for CloudFront, ALB, or A records

> `www` is not created automatically. Add it explicitly via `subdomains`.

## Requirements

- Terraform `>= 1.0`
- AWS provider `~> 5.0`
- Random provider `~> 3.0`

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

  domain_name        = "example.com"
  bucket_name        = "example-com-website"
  deploy_to_prod     = true
  deploy_hosted_zone = true
  enable_waf         = true

  subdomains = [
    {
      name        = "www"
      target_type = "cloudfront"
    }
  ]
}
```

### Production — existing hosted zone

Use when the Route 53 zone already exists to avoid recreation.

```hcl
module "static_website" {
  source = "./modules/terraform-aws-static-website"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name        = "example.com"
  bucket_name        = "example-com-website"
  deploy_to_prod     = true
  deploy_hosted_zone = false
  existing_zone_id   = "Z08578232AQ4K9C2854A3"
  enable_waf         = true
}
```

### Production — with API Gateway origin

Routes `/api/*` to API Gateway, everything else to S3.

The module auto-generates a secret per origin, injects it as `x-origin-secret` custom header from CloudFront, and stores it in SSM Parameter Store. Your API Gateway resource policy uses this secret to deny any request not coming through CloudFront.

```hcl
module "static_website" {
  source = "./modules/terraform-aws-static-website"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name        = "app.example.com"
  bucket_name        = "example-com-website"
  deploy_to_prod     = true
  deploy_hosted_zone = true
  enable_waf         = true

  api_origins = [
    {
      origin_id       = "main-api"
      api_gateway_url = "https://abc123.execute-api.eu-west-1.amazonaws.com/prod"
      path_patterns   = ["/api/*"]
    }
  ]
}

# In your API Gateway Terraform — read the secret value from SSM
data "aws_ssm_parameter" "origin_secret" {
  name = module.static_website.api_origin_secret_names["main-api"]
}

# Enforce CloudFront-only access via API Gateway resource policy
resource "aws_api_gateway_rest_api_policy" "api_policy" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.main.execution_arn}/*"
      },
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.main.execution_arn}/*"
        Condition = {
          StringNotEquals = {
            "aws:RequestHeader/x-origin-secret" = data.aws_ssm_parameter.origin_secret.value
          }
        }
      }
    ]
  })
}
```

### Production — with subdomains, email, and DNSSEC

```hcl
module "static_website" {
  source = "./modules/terraform-aws-static-website"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name        = "example.com"
  bucket_name        = "example-com-website"
  deploy_to_prod     = true
  deploy_hosted_zone = true
  enable_waf         = true
  enable_dnssec      = true

  subdomains = [
    {
      name        = "www"
      target_type = "cloudfront"
    },
    {
      name        = "app"
      target_type = "cloudfront"
    },
    {
      name         = "api"
      target_type  = "alb"
      alb_dns_name = "my-alb-123.eu-west-1.elb.amazonaws.com"
      alb_zone_id  = "Z32O12XQLNTSW2"
    }
  ]

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
| `deploy_to_prod` | bool | `false` | Enable ACM certificate, Route 53 records and CloudFront custom domain aliases |
| `deploy_hosted_zone` | bool | `false` | Create a Route 53 hosted zone for the domain |
| `existing_zone_id` | string | `null` | Use an existing Route 53 hosted zone instead of creating a new one |
| `website_setup` | map(string) | `{ index_document = "index.html", error_document = "error.html" }` | Website root and error document names |
| `tags` | map(string) | `{}` | Tags to assign to AWS resources |
| `subdomains` | list(object) | `[]` | Optional subdomain configuration for CloudFront, ALB, or A records |
| `include_email_records` | bool | `false` | Create email-related DNS records |
| `email_records` | object | `null` | Email DNS configuration (required if `include_email_records = true`) |
| `log_retention_days` | number | `90` | S3 and CloudFront log retention days |
| `enable_log_bucket` | bool | `true` | Create an S3 logging bucket for S3 and CloudFront access logs |
| `prevent_bucket_destroy` | bool | `true` | Protect S3 buckets from accidental destruction |
| `content_security_policy` | string | `default-src 'self'; ...` | Content-Security-Policy header value |
| `enable_dnssec` | bool | `false` | Enable DNSSEC on the hosted zone |
| `dnssec_kms_key_arn` | string | `null` | Existing KMS key ARN for DNSSEC signing |
| `enable_waf` | bool | `false` | Attach an AWS WAF Web ACL to CloudFront |
| `api_origins` | list(object) | `[]` | API Gateway origins to attach to CloudFront |

### `api_origins` object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `origin_id` | string | required | Unique identifier for the origin |
| `api_gateway_url` | string | required | Full HTTPS URL of the API Gateway stage |
| `path_patterns` | list(string) | required | CloudFront path patterns to route to this origin |
| `allowed_methods` | list(string) | all methods | HTTP methods to allow |

### `subdomains` object

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Subdomain label (e.g. `www`, `app`) |
| `target_type` | string | `cloudfront`, `alb`, or `a_record` |
| `alb_dns_name` | string | Required when `target_type = "alb"` |
| `alb_zone_id` | string | Required when `target_type = "alb"` |
| `a_record_ips` | list(string) | Required when `target_type = "a_record"` |

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
| `website_url` | Website URL (`https://<domain>` in prod, CloudFront URL otherwise) |
| `s3_bucket_name` | Website S3 bucket name |
| `s3_bucket_arn` | Website S3 bucket ARN |
| `s3_log_bucket_name` | Access log S3 bucket name (`null` when `enable_log_bucket = false`) |
| `route53_zone_id` | Route 53 hosted zone ID |
| `route53_nameservers` | Hosted zone nameservers (when created) |
| `api_origin_secret_names` | Map of SSM Parameter names for each API origin secret — use in your API Gateway resource policy |
| `subdomain_fqdns` | FQDNs of all created subdomains |

## Notes

- Set `deploy_to_prod = true` to enable ACM, custom domain aliases, and Route 53 records.
- Set `deploy_to_prod = false` to use the default CloudFront URL (e.g. for dev/staging).
- Use `existing_zone_id` with `deploy_hosted_zone = false` if the zone already exists in Route 53.
- API Gateway origins are secured with a per-origin secret injected by CloudFront as `x-origin-secret`. Use `api_origin_secret_names` to read the secret value from SSM and enforce it in your API Gateway resource policy.
- `enable_log_bucket = false` disables the log bucket, S3 access logging, and CloudFront logging entirely.
- `prevent_bucket_destroy = false` allows Terraform to destroy both the log and website buckets (use with caution).
- `enable_dnssec` requires `deploy_hosted_zone = true`.
