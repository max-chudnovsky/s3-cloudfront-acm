# ACM Certificate Module for Multi-Domain SSL
# NOTE: ACM certificates for CloudFront must be created in us-east-1

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ACM Certificate for all domains
resource "aws_acm_certificate" "main" {
  domain_name               = var.domains[0]
  subject_alternative_names = length(var.domains) > 1 ? slice(var.domains, 1, length(var.domains)) : []
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-certificate"
    Environment = var.environment
    Project     = var.project_name
  }
}
