# Security response headers policy (HSTS, X-Frame-Options, CSP, etc.)
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "${var.bucket_name}-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
    content_security_policy {
      content_security_policy = var.content_security_policy
      override                = true
    }
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = "${var.domain_name}-oac"
  description                       = "OAC for ${var.domain_name} static website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website_distribution" {
  depends_on = [aws_s3_bucket_policy.log_bucket_policy]
  origin {
    domain_name              = local.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
    origin_id                = "S3-${local.website_bucket.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.website_setup["index_document"]
  aliases = var.deploy_to_prod ? concat(
    [var.domain_name],
    [for s in var.subdomains : "${s.name}.${var.domain_name}" if s.target_type == "cloudfront"]
  ) : []

  # checkov CKV_AWS_68 / tfsec aws-cloudfront-enable-waf
  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.cloudfront_waf[0].arn : null

  # checkov CKV_AWS_86 / tfsec aws-cloudfront-enable-logging
  dynamic "logging_config" {
    for_each = var.enable_log_bucket ? [1] : []
    content {
      bucket          = local.log_bucket.bucket_domain_name
      include_cookies = false
      prefix          = "cloudfront-access-logs/"
    }
  }

  default_cache_behavior {
    allowed_methods                = ["GET", "HEAD"]
    cached_methods                 = ["GET", "HEAD"]
    target_origin_id               = "S3-${local.website_bucket.bucket}"
    compress                       = true
    viewer_protocol_policy         = "redirect-to-https"
    response_headers_policy_id     = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # S3 OAC returns 403 for missing objects, remap to 404
  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/${var.website_setup["error_document"]}"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/${var.website_setup["error_document"]}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.deploy_to_prod ? aws_acm_certificate_validation.website_cert_validation[0].certificate_arn : null
    ssl_support_method             = var.deploy_to_prod ? "sni-only" : null
    cloudfront_default_certificate = !var.deploy_to_prod
    # TLSv1.2_2021 is only valid with a custom cert; default CF cert requires TLSv1
    minimum_protocol_version = var.deploy_to_prod ? "TLSv1.2_2021" : "TLSv1"
  }

  tags = var.tags
}
