provider "aws" {
}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_s3_bucket" "files" {
  force_destroy = "true"
}

resource "aws_s3_object" "file" {
  key          = "oac/index.html"
  content      = <<EOF
<html>
<body>
Hello OAC!
</body>
</html>
EOF
  bucket       = aws_s3_bucket.files.bucket
  content_type = "text/html"
}

resource "aws_s3_object" "file2" {
  key          = "oai/index.html"
  content      = <<EOF
<html>
<body>
Hello OAI!
</body>
</html>
EOF
  bucket       = aws_s3_bucket.files.bucket
  content_type = "text/html"
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "files-bucket-${random_id.id.hex}"
  description                       = ""
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_identity" "oai" {
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name              = aws_s3_bucket.files.bucket_regional_domain_name
    origin_id                = "files_oac"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }
  origin {
    domain_name = aws_s3_bucket.files.bucket_regional_domain_name
    origin_id   = "files_oai"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled = true

  ordered_cache_behavior {
    path_pattern     = "/oai/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "files_oai"

    default_ttl = 0
    min_ttl     = 0
    max_ttl     = 0

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "files_oac"

    default_ttl = 0
    min_ttl     = 0
    max_ttl     = 0

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  http_version    = "http2and3"
  price_class     = "PriceClass_100"
  is_ipv6_enabled = true
}

resource "aws_s3_bucket_policy" "default" {
  bucket = aws_s3_bucket.files.id
  policy = data.aws_iam_policy_document.default.json
}

data "aws_iam_policy_document" "default" {
  statement {
    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.files.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.distribution.arn]
    }
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.files.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

output "domain_name" {
  value = aws_cloudfront_distribution.distribution.domain_name
}

