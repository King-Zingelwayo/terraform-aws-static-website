variable "domain_name" {
  description = "The domain name for the website"
  type        = string
}

variable "bucket_name" {
  description = "The name of the S3 bucket for static website hosting"
  type        = string
}

variable "website_oac_name" {
  description = "Deprecated: OAC name is now derived from domain_name internally. This variable is ignored."
  type        = any
  default     = null
}

variable "website_setup" {
  description = "Configuration for website setup"
  type        = map(string)
  default     = {
    index_document = "index.html"
    error_document = "error.html"
  }

  validation {
    condition     = contains(keys(var.website_setup), "index_document") && contains(keys(var.website_setup), "error_document")
    error_message = "The website_setup map must contain 'index_document' and 'error_document' keys."
  }
}
variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}
variable "enable_acm" {
  description = "Enable ACM certificate and HTTPS for CloudFront"
  type        = bool
  default     = false
}
variable "zone_id" {
  description = "Route 53 hosted zone ID to create DNS records in. Required when enable_acm is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_acm || var.zone_id != null
    error_message = "zone_id is required when enable_acm is true."
  }
}

variable "subdomains" {
  description = "Additional CloudFront subdomain aliases to create as Route 53 records"
  type        = list(string)
  default     = []
}

variable "logging" {
  description = "Central logging bucket configuration. Set enabled = true and provide bucket details to activate logging for S3, CloudFront, and WAF."
  type = object({
    enabled            = bool
    bucket_id          = optional(string)
    bucket_arn         = optional(string)
    bucket_domain_name = optional(string)
    s3_prefix          = optional(string, "s3-access-logs/")
    cloudfront_prefix  = optional(string, "cloudfront-access-logs/")
    waf_prefix         = optional(string, "waf-logs/")
  })
  default = {
    enabled = false
  }

  validation {
    condition     = !var.logging.enabled || (var.logging.bucket_id != null && var.logging.bucket_arn != null && var.logging.bucket_domain_name != null)
    error_message = "logging.bucket_id, logging.bucket_arn, and logging.bucket_domain_name are required when logging.enabled is true."
  }
}

variable "content_security_policy" {
  description = "Content-Security-Policy header value applied via CloudFront response headers policy"
  type        = string
  default     = "default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'; object-src 'none'"
}


variable "enable_waf" {
  description = "Create a WAF Web ACL with AWS managed rules and attach it to the CloudFront distribution"
  type        = bool
  default     = false
}

variable "email_records" {
  description = "Email DNS records configuration"
  type = object({
    mx_record = object({
      priority = number
      value    = string
    })
    webmail_ip = string
    mail_ip    = string
  })
  default = null

  // Validation to ensure that if email_records is provided, all required fields are present
  validation {
    condition     = var.email_records == null || (var.email_records.mx_record != null && var.email_records.webmail_ip != null && var.email_records.mail_ip != null)
    error_message = "If email_records is provided, mx_record, webmail_ip, and mail_ip must all be specified."
  }
}