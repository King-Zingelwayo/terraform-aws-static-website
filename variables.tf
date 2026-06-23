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

variable "include_email_records" {
  description = "Whether to create email DNS records"
  type        = bool
  default     = false
}

variable "prevent_bucket_destroy" {
  description = "should this bucket be destroyable?"
  type = bool
  default = true
}

variable "enable_log_bucket" {
  description = "Create and attach an S3 logging bucket for S3 and CloudFront access logs"
  type        = bool
  default     = true
}
variable "log_retention_days" {
  description = "Number of days to retain S3 and CloudFront access logs"
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days > 0
    error_message = "log_retention_days must be greater than 0."
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

variable "api_origins" {
  description = "API Gateway origins to attach to CloudFront"
  type = list(object({
    origin_id       = string
    api_gateway_url = string
    path_patterns   = list(string)
    allowed_methods = optional(list(string), ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
  }))
  default = []

  validation {
    condition     = alltrue([for o in var.api_origins : startswith(o.api_gateway_url, "https://")])
    error_message = "api_gateway_url must start with https://."
  }
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

  validation {
    condition     = var.include_email_records ? var.email_records != null : true
    error_message = "email_records must be provided when include_email_records is true."
  }
}