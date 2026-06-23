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
  origin {
    domain_name              = local.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
    origin_id                = "S3-${local.website_bucket.bucket}"
  }

  # API Gateway origins
  dynamic "origin" {
    for_each = { for o in var.api_origins : o.origin_id => o }
    content {
      domain_name = regex("https?://([^/]+)", origin.value.api_gateway_url)[0]
      origin_id   = origin.value.origin_id
      origin_path = regex("https?://[^/]+(/.+)", origin.value.api_gateway_url)[0]

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.website_setup["index_document"]
  aliases = var.enable_acm ? concat([var.domain_name], [for s in var.subdomains : "${s}.${var.domain_name}"]) : []

  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.cloudfront_waf[0].arn : null
  dynamic "logging_config" {
    for_each = local.logging_enabled ? [1] : []
    content {
      bucket          = var.logging.bucket_domain_name
      include_cookies = false
      prefix          = var.logging.cloudfront_prefix
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

  # API Gateway cache behaviours — one per path pattern per origin
  dynamic "ordered_cache_behavior" {
    for_each = flatten([
      for o in var.api_origins : [
        for path in o.path_patterns : {
          origin_id       = o.origin_id
          path_pattern    = path
          allowed_methods = o.allowed_methods
        }
      ]
    ])
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.origin_id
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ["GET", "HEAD"]
      viewer_protocol_policy = "redirect-to-https"
      compress               = true

      # Disable caching for API responses
      cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled managed policy
      origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewerExceptHostHeader managed policy
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
    acm_certificate_arn            = var.enable_acm ? aws_acm_certificate_validation.website_cert_validation[0].certificate_arn : null
    ssl_support_method             = var.enable_acm ? "sni-only" : null
    cloudfront_default_certificate = !var.enable_acm
    minimum_protocol_version = var.enable_acm ? "TLSv1.2_2021" : "TLSv1"
  }

  tags = var.tags
}
