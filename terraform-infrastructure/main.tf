terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "testproject-terraform-state-f0fa1141"
    key     = "infrastructure/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

# ACM Certificate Module (must be in us-east-1 for CloudFront)
module "acm" {
  count  = var.create_acm_certificate ? 1 : 0
  source = "./modules/acm"

  providers = {
    aws = aws.us_east_1
  }

  project_name = var.project_name
  environment  = var.environment
  domains      = var.use_wildcard_certificate ? ["*.${var.wildcard_domain}"] : local.certificate_domains
}

# S3 Bucket Module (created first, without bucket policy)
module "s3" {
  source = "./modules/s3"

  bucket_name            = local.s3_bucket_name
  environment            = var.environment
  project_name           = var.project_name
  enable_versioning      = var.enable_s3_versioning
  enable_lifecycle_rules = var.enable_s3_lifecycle_rules
}

# CloudFront Distribution Module
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name                      = var.project_name
  environment                       = var.environment
  domain_names                      = local.active_domains
  s3_bucket_id                      = module.s3.bucket_id
  s3_bucket_regional_domain_name    = module.s3.bucket_regional_domain_name
  acm_certificate_arn               = var.create_acm_certificate ? module.acm[0].certificate_arn : var.existing_acm_certificate_arn
  enable_ipv6                       = var.enable_ipv6
  price_class                       = var.cloudfront_price_class
  enable_logging                    = var.enable_cloudfront_logging
  allow_http_for_testing            = var.allow_http_for_testing
  force_aliases_without_certificate = var.force_aliases_without_certificate
  # Automatically attach custom domains when certificate is validated
  use_custom_domains = local.certificate_is_validated
}

# Sync content to S3 after infrastructure is ready
# S3 Bucket Policy for CloudFront OAC access
# Created separately to avoid circular dependency
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = module.s3.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })

  depends_on = [module.cloudfront]
}