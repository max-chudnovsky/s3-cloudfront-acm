variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "domain_names" {
  description = "List of domain names (CNAMEs) for the distribution"
  type        = list(string)
}

variable "s3_bucket_id" {
  description = "ID of the S3 bucket to use as origin"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for SSL"
  type        = string
}

variable "enable_ipv6" {
  description = "Enable IPv6 for the distribution"
  type        = bool
  default     = true
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
}

variable "enable_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "logging_bucket_domain_name" {
  description = "Domain name of the S3 bucket for logging"
  type        = string
  default     = ""
}

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

variable "use_custom_domains" {
  description = "Attach custom domains and ACM certificate to CloudFront (set to true after ACM validation completes)"
  type        = bool
  default     = false
}
