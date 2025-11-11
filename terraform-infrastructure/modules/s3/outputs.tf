output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.static_content.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.static_content.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.static_content.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket regional domain name"
  value       = aws_s3_bucket.static_content.bucket_regional_domain_name
}
