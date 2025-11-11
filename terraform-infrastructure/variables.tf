variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "testproject"
}

# Domain Configuration
variable "config_directory" {
  description = "Path to directory containing domain configurations"
  type        = string
  default     = "../config"
}

variable "manual_domains" {
  description = "Manually specified domain names (used if auto-discovery fails)"
  type        = list(string)
  default     = []
}

# S3 Configuration
variable "static_content_bucket" {
  description = "Name of the S3 bucket for static content (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "enable_s3_versioning" {
  description = "Enable S3 bucket versioning for content management"
  type        = bool
  default     = true
}

variable "enable_s3_lifecycle_rules" {
  description = "Enable lifecycle rules for cost optimization"
  type        = bool
  default     = true
}

# CloudFront Configuration
variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
}

variable "enable_ipv6" {
  description = "Enable IPv6 for CloudFront distribution"
  type        = bool
  default     = true
}

variable "enable_cloudfront_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

# ACM Certificate Configuration
variable "create_acm_certificate" {
  description = "Whether to create ACM certificate (set to false if using existing certificate)"
  type        = bool
  default     = true
}

variable "existing_acm_certificate_arn" {
  description = "ARN of existing ACM certificate (used if create_acm_certificate is false)"
  type        = string
  default     = ""
}

variable "use_wildcard_certificate" {
  description = "Use wildcard certificate (*.domain.com) instead of individual domain certificates"
  type        = bool
  default     = false
}

variable "wildcard_domain" {
  description = "Base domain for wildcard certificate (e.g., 'example.com' for *.example.com)"
  type        = string
  default     = ""
}

# Testing Configuration
variable "allow_http_for_testing" {
  description = "Allow HTTP (not just HTTPS) for testing without certificate"
  type        = bool
  default     = false
}

variable "force_aliases_without_certificate" {
  description = "Force adding domain aliases even without ACM certificate (for HTTP-only testing)"
  type        = bool
  default     = false
}
