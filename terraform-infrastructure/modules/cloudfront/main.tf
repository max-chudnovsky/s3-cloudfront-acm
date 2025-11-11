# CloudFront Module for Multi-Domain Static Content Distribution

# Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-s3-oac"
  description                       = "OAC for ${var.project_name} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Function for path rewriting and domain routing
resource "aws_cloudfront_function" "url_rewrite" {
  name    = "${var.project_name}-url-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "URL rewriting for multi-domain routing"
  publish = true
  code    = file("${path.module}/functions/url-rewrite.js")
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  comment             = "${var.project_name} multi-domain static content distribution"
  default_root_object = "index.html"
  price_class         = var.price_class
  
  # Only set aliases after ACM certificate is validated (controlled by use_custom_domains variable)
  aliases             = var.use_custom_domains ? var.domain_names : []

  # S3 Origin
  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "S3-${var.s3_bucket_id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id

    # Custom headers for origin
    custom_header {
      name  = "X-Origin-Verify"
      value = var.project_name
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = var.allow_http_for_testing ? "allow-all" : "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600      # 1 hour
    max_ttl                = 86400     # 24 hours
    compress               = true

    # Attach URL rewrite function
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.url_rewrite.arn
    }
  }

  # SSL Certificate
  viewer_certificate {
    # Use ACM certificate with custom domains, or CloudFront default certificate
    acm_certificate_arn            = var.use_custom_domains ? var.acm_certificate_arn : null
    cloudfront_default_certificate = !var.use_custom_domains
    ssl_support_method             = var.use_custom_domains ? "sni-only" : null
    minimum_protocol_version       = var.use_custom_domains ? "TLSv1.2_2021" : "TLSv1"
  }

  # Restrictions (geo-restrictions if needed)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Logging configuration
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      include_cookies = false
      bucket          = var.logging_bucket_domain_name
      prefix          = "cloudfront/"
    }
  }

  tags = {
    Name        = "${var.project_name}-cdn"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Cache Policy for static content
resource "aws_cloudfront_cache_policy" "static_content" {
  name        = "${var.project_name}-static-content-policy"
  comment     = "Cache policy for static content with long TTL"
  default_ttl = 86400   # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

# Origin Request Policy
resource "aws_cloudfront_origin_request_policy" "main" {
  name    = "${var.project_name}-origin-request-policy"
  comment = "Origin request policy for ${var.project_name}"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]
    }
  }

  query_strings_config {
    query_string_behavior = "none"
  }
}

# Response Headers Policy for security
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.project_name}-security-headers"
  comment = "Security headers for ${var.project_name}"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_max_age_sec = 3600
    origin_override            = true
  }

  custom_headers_config {
    items {
      header   = "X-Custom-Header"
      value    = var.project_name
      override = true
    }
  }
}
