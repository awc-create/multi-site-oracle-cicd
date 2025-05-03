output "bucket_name" {
  value = aws_s3_bucket.site.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.cdn.domain_name
}
