provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

resource "aws_cloudfront_origin_access_identity" "cf_origin_access_identity" {
  comment = "cf_origin_access_identity"
}

data "aws_iam_policy_document" "allow_access_to_public" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.cf_origin_access_identity.iam_arn]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}

data "aws_cloudfront_origin_request_policy" "cf_origin_request_policy" {
  name = "Managed-CORS-S3Origin"
}

# pre-existing policy defined by AWS
data "aws_cloudfront_cache_policy" "cf_cache_policy" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_response_headers_policy" "cf_response_headers_policy" {
  name = "Managed-SimpleCORS"
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.AWS_S3_BUCKET_NAME
  acl    = "private"

  tags = {
    Name = var.AWS_S3_BUCKET_NAME
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.allow_access_to_public.json
}

resource "aws_s3_bucket_object" "index_file" {
  bucket       = aws_s3_bucket.bucket.id
  key          = "index.html"
  source       = "static/index.html"
  etag         = filemd5("static/index.html")
  content_type = "text/html charset=utf-8"
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.bucket.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cf_origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.bucket.bucket

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    compress               = true

    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.cf_origin_request_policy.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cf_response_headers_policy.id
    cache_policy_id            = data.aws_cloudfront_cache_policy.cf_cache_policy.id
  }

  price_class = "PriceClass_All"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      # locations        = ["US", "CA", "GB", "DE"]
    }
  }
}
