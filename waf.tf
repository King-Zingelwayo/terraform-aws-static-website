resource "aws_wafv2_web_acl" "cloudfront_waf" {
  count    = var.enable_waf ? 1 : 0
  provider = aws.us_east_1

  name        = "${var.bucket_name}-waf"
  description = "WAF Web ACL for ${var.domain_name} CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # 1. AWS Common Rule Set — protects against OWASP Top 10
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 2. Known Bad Inputs — blocks Log4Shell, Spring4Shell, SSRF patterns
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 3. Amazon IP Reputation List — blocks bots, scrapers, malicious IPs
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 30
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # 4. Anonymous IP List — blocks Tor exit nodes, VPNs, hosting proxies
  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 40
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.bucket_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, { Name = "${var.bucket_name}-waf" })
}

# WAF logging
resource "aws_wafv2_web_acl_logging_configuration" "cloudfront_waf_logging" {
  count                   = var.enable_waf && local.logging_enabled ? 1 : 0
  provider                = aws.us_east_1
  log_destination_configs = [var.logging.bucket_arn]
  resource_arn            = aws_wafv2_web_acl.cloudfront_waf[0].arn
}
