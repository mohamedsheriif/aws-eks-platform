resource "aws_cloudfront_origin_access_control" "this" {
  for_each = var.origin_access_controls

  name                              = each.value.name
  description                       = each.value.description
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  for_each = var.cloudfront_distributions

  comment             = each.value.comment
  enabled             = each.value.enabled
  is_ipv6_enabled     = each.value.is_ipv6_enabled
  wait_for_deployment = each.value.wait_for_deployment
  aliases             = each.value.aliases
  http_version        = each.value.http_version
  price_class         = each.value.price_class
  default_root_object = each.value.default_root_object

  dynamic "origin" {
    for_each = each.value.origins
    content {
      domain_name              = origin.value.origin_domain_name
      origin_id                = origin.value.origin_id
      origin_path              = origin.value.origin_path
      origin_access_control_id = aws_cloudfront_origin_access_control.this[origin.value.origin_access_control_key].id
    }
  }

  default_cache_behavior {
    target_origin_id           = each.value.default_cache_behavior.target_origin_id
    viewer_protocol_policy     = each.value.default_cache_behavior.viewer_protocol_policy
    allowed_methods            = each.value.default_cache_behavior.allowed_methods
    cached_methods             = each.value.default_cache_behavior.cached_methods
    compress                   = each.value.default_cache_behavior.compress
    cache_policy_id            = each.value.default_cache_behavior.cache_policy_id
    origin_request_policy_id   = each.value.default_cache_behavior.origin_request_policy_id
    response_headers_policy_id = each.value.default_cache_behavior.response_headers_policy_id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = each.value.viewer_certificate.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = each.value.viewer_certificate.minimum_protocol_version
  }

  tags = merge({
    Name = format("%s-%s-%s-cloudfront", var.project, var.env, each.key)
  }, var.tags)
}
