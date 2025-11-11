# Local variables for domain discovery and configuration

locals {
  # Discover domains from config directory structure
  config_path = "${path.module}/${var.config_directory}"

  # Get list of domain directories by finding */index.html files
  # Then extract the directory name (domain)
  discovered_domains = [
    for file_path in fileset(local.config_path, "*/index.html") :
    dirname(file_path)
  ]

  # For certificate: use discovered domains (Terraform will handle additions gracefully)
  # Removing domains from certificate requires manual intervention to avoid outages
  certificate_domains = local.discovered_domains

  # Use current discovered domains for CloudFront aliases and Route53 (can shrink)
  active_domains = local.discovered_domains

  # Use discovered domains or fallback to manually specified domains
  domains = length(local.discovered_domains) > 0 ? local.discovered_domains : var.manual_domains

  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # S3 bucket name
  s3_bucket_name = var.static_content_bucket != "" ? var.static_content_bucket : "${var.project_name}-static-content"

  # Check if we should use custom domains (certificate must be validated)
  # This uses the created certificate's status from state, not a data source lookup
  certificate_is_validated = var.create_acm_certificate ? (
    try(module.acm[0].certificate_status == "ISSUED", false)
  ) : (var.existing_acm_certificate_arn != "")
}
