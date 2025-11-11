# Output values for the infrastructure

output "s3_bucket_name" {
  description = "Name of the S3 bucket for static content"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.bucket_arn
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_domain" {
  description = "Domain name of the CloudFront distribution"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = module.cloudfront.distribution_arn
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = var.create_acm_certificate ? module.acm[0].certificate_arn : var.existing_acm_certificate_arn
}

output "discovered_domains" {
  description = "List of domains discovered from config directory"
  value       = local.domains
}

output "deployment_instructions" {
  description = "Instructions for deploying content to S3"
  value = local.certificate_is_validated ? (
    <<-EOT
    
    ═══════════════════════════════════════════════════════════════════════════════
                            DEPLOYMENT COMPLETE - LIVE!
    ═══════════════════════════════════════════════════════════════════════════════

    ✓ S3 Bucket: ${module.s3.bucket_id}
    ✓ CloudFront Distribution: ${module.cloudfront.distribution_id}
    ✓ ACM Certificate: VALIDATED
    ✓ Custom Domains: ATTACHED

    ───────────────────────────────────────────────────────────────────────────────
                    YOUR SITES ARE NOW LIVE
    ───────────────────────────────────────────────────────────────────────────────

    %{for domain in local.domains~}
    ✓ https://${domain}
    %{endfor~}

    CloudFront Distribution: https://${module.cloudfront.distribution_domain_name}

  EOT
    ) : (
    <<-EOT
    
    ═══════════════════════════════════════════════════════════════════════════════
                            DEPLOYMENT COMPLETE
    ═══════════════════════════════════════════════════════════════════════════════

    ✓ S3 Bucket: ${module.s3.bucket_id}
    ✓ CloudFront Distribution: ${module.cloudfront.distribution_id}
    ✓ CloudFront Domain: ${module.cloudfront.distribution_domain_name}
    ✓ ACM Certificate: ${var.create_acm_certificate ? "PENDING VALIDATION" : "Using existing"}

    ───────────────────────────────────────────────────────────────────────────────
                    NEXT STEPS - ADD TO OCTODNS
    ───────────────────────────────────────────────────────────────────────────────

    See outputs below for DNS records to add to your OctoDNS configuration.

  EOT
  )
}

# DNS Configuration - OctoDNS YAML Format
output "octodns_domain_records" {
  description = "Domain CNAME records for OctoDNS (YAML format) - only shown when certificate is pending"
  value = local.certificate_is_validated ? "✓ Custom domains already attached to CloudFront" : (
    <<-EOT

    ═══════════════════════════════════════════════════════════════════════════════
                    OCTODNS CONFIGURATION - DOMAIN RECORDS
    ═══════════════════════════════════════════════════════════════════════════════

    Add these records to your OctoDNS YAML files:

    %{for domain in local.domains~}
    # File: ${replace(domain, "/^[^.]+\\./", "")}.yaml
    ---
    ${split(".", domain)[0]}:
      type: CNAME
      ttl: 3600
      value: ${module.cloudfront.distribution_domain_name}.

    %{endfor~}
  EOT
  )
}

output "octodns_validation_records" {
  description = "ACM validation records for OctoDNS (YAML format) - only shown when certificate is pending"
  value = local.certificate_is_validated ? "✓ Certificate already validated" : (
    var.create_acm_certificate ? join("\n", [
      "",
      "═══════════════════════════════════════════════════════════════════════════════",
      "            ACM VALIDATION RECORDS FOR OCTODNS",
      "═══════════════════════════════════════════════════════════════════════════════",
      "",
      "Add these validation records to your OctoDNS YAML files:",
      "",
      join("\n\n", [for dvo in module.acm[0].domain_validation_options :
        join("\n", [
          "# For domain: ${dvo.domain_name}",
          "# Add to file: ${replace(dvo.domain_name, "/^[^.]+\\./", "")}.yaml",
          "",
          "${replace(replace(dvo.resource_record_name, "/.$/", ""), "/\\.[^.]+\\.[^.]+$/", "")}:",
          "  type: ${dvo.resource_record_type}",
          "  ttl: 3600",
          "  value: ${dvo.resource_record_value}"
        ])
      ]),
      ""
    ]) : "ACM certificate not created - using existing certificate"
  )
}

output "dns_records_summary" {
  description = "Quick reference for DNS records - only shown when certificate is pending"
  value = local.certificate_is_validated ? "✓ All DNS records configured and domains live" : (
    <<-EOT

    ═══════════════════════════════════════════════════════════════════════════════
                        DNS RECORDS QUICK REFERENCE
    ═══════════════════════════════════════════════════════════════════════════════

    CloudFront Distribution: ${module.cloudfront.distribution_domain_name}
    
    Domains Configured: ${length(local.domains)}
    %{for domain in local.domains~}
      - ${domain}
    %{endfor~}

    For each domain, add to OctoDNS:
      ${join("\n      ", [for d in local.domains : "${d} → CNAME → ${module.cloudfront.distribution_domain_name}"])}

    ${var.create_acm_certificate ? "ACM Validation Records: ${length(module.acm[0].domain_validation_options)} records (see octodns_validation_records output)" : ""}

    ═══════════════════════════════════════════════════════════════════════════════

  EOT
  )
}
