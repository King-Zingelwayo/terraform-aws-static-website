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
variable "deploy_to_prod" {
  description = "Deploy to production with ACM certificate and Route 53"
  type        = bool
  default     = false
}
variable "deploy_hosted_zone" {
  description = "Deploy Route 53 hosted zone"
  type        = bool
  default     = false
}

variable "existing_zone_id" {
  description = "ID of an existing Route 53 hosted zone to use instead of creating a new one"
  type        = string
  default     = null
}

variable "subdomains" {
  description = "Optional subdomains to create as Route 53 alias or A records"
  type = list(object({
    name        = string
    target_type = string # "cloudfront", "alb", or "a_record"
    alb_dns_name = optional(string)
    alb_zone_id  = optional(string)
    a_record_ips = optional(list(string))
  }))
  default = []

  validation {
    condition = alltrue([
      for s in var.subdomains : contains(["cloudfront", "alb", "a_record"], s.target_type)
    ])
    error_message = "target_type must be one of: cloudfront, alb, a_record."
  }

  validation {
    condition = alltrue([
      for s in var.subdomains :
      s.target_type == "alb" ? (s.alb_dns_name != null && s.alb_zone_id != null) : true
    ])
    error_message = "alb_dns_name and alb_zone_id are required when target_type is alb."
  }

  validation {
    condition = alltrue([
      for s in var.subdomains :
      s.target_type == "a_record" ? s.a_record_ips != null : true
    ])
    error_message = "a_record_ips is required when target_type is a_record."
  }
}

variable "include_email_records" {
  description = "Whether to create email DNS records"
  type        = bool
  default     = false
}

variable "log_bucket_prevent_destroy" {
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

variable "enable_dnssec" {
  description = "Enable DNSSEC on the Route 53 hosted zone. A KMS key will be auto-created unless dnssec_kms_key_arn is provided."
  type        = bool
  default     = false
}

variable "dnssec_kms_key_arn" {
  description = "ARN of an existing KMS key (ECC_NIST_P256, us-east-1) for DNSSEC. If null and enable_dnssec is true, a key is created automatically."
  type        = string
  default     = null
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

  validation {
    condition     = var.include_email_records ? var.email_records != null : true
    error_message = "email_records must be provided when include_email_records is true."
  }
}