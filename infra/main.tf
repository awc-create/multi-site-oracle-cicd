provider "aws" {
  region = "eu-west-2"
}

resource "aws_s3_bucket" "site" {
  bucket = var.project_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "404.html"
  }

  tags = {
    Name = var.project_name
  }
}

resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "PublicReadGetObject",
        Effect: "Allow",
        Principal: "*",
        Action: "s3:GetObject",
        Resource: "${aws_s3_bucket.site.arn}/*"
      }
    ]
  })
}

# Optional: ACM cert in us-east-1 for CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1
  domain_name       = var.project_name
  validation_method = "DNS"
}

# CloudFront
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = "${aws_s3_bucket.site.bucket_regional_domain_name}"
    origin_id   = var.project_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.project_name

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.cert.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }
}
