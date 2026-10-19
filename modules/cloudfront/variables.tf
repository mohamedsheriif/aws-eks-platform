variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "origin_access_controls" {
  description = "Map of S3 Origin Access Controls (SigV4), referenced by origins via origin_access_control_key"
  type = map(object({
    # (Required) The name of the origin access control.
    name = string

    # (Optional) A description of the origin access control. Defaults to "".
    description = optional(string, "")
  }))
  default = {}
}

variable "cloudfront_distributions" {
  description = "Map of CloudFront distributions in front of private S3 origins"
  type = map(object({
    # (Optional) A comment to describe the distribution. Defaults to "".
    comment = optional(string, "")

    # (Optional) Whether the distribution is enabled. Defaults to true.
    enabled = optional(bool, true)

    # (Optional) Whether IPv6 is enabled. Defaults to false.
    is_ipv6_enabled = optional(bool, false)

    # (Optional) Whether to wait for the distribution to reach a deployed state. Defaults to false.
    wait_for_deployment = optional(bool, false)

    # (Optional) The HTTP version to use (e.g., http2, http2and3). Defaults to "http2".
    http_version = optional(string, "http2")

    # (Optional) The price class for the distribution. Defaults to "PriceClass_100".
    price_class = optional(string, "PriceClass_100")

    # (Optional) Object returned for requests to the root URL. Defaults to null.
    default_root_object = optional(string, null)

    # (Optional) Alternate domain names for the distribution. Defaults to [].
    aliases = optional(list(string), [])

    # (Optional) Route 53 zone to publish an alias record into for every entry in aliases. Defaults to null.
    route53_zone_id = optional(string, null)

    # (Required) Map of S3 origins for the distribution.
    origins = map(object({
      # (Required) A unique identifier for the origin.
      origin_id = string

      # (Required) The bucket regional domain name.
      origin_domain_name = string

      # (Optional) The path that CloudFront appends to the origin domain. Defaults to "".
      origin_path = optional(string, "")

      # (Required) The key of an entry in var.origin_access_controls.
      origin_access_control_key = string
    }))

    # (Required) The default cache behavior for the distribution.
    default_cache_behavior = object({
      # (Required) The origin ID that CloudFront routes requests to by default.
      target_origin_id = string

      # (Optional) The protocol policy for viewers. Defaults to "redirect-to-https".
      viewer_protocol_policy = optional(string, "redirect-to-https")

      # (Optional) The HTTP methods CloudFront processes and forwards. Defaults to GET/HEAD/OPTIONS.
      allowed_methods = optional(list(string), ["GET", "HEAD", "OPTIONS"])

      # (Optional) The HTTP methods CloudFront caches responses for. Defaults to GET/HEAD.
      cached_methods = optional(list(string), ["GET", "HEAD"])

      # (Optional) Whether CloudFront compresses content automatically. Defaults to true.
      compress = optional(bool, true)

      # (Required) The ID of the cache policy to attach (e.g. Managed-CachingOptimized).
      cache_policy_id = string

      # (Optional) The ID of the origin request policy to attach. Defaults to null.
      origin_request_policy_id = optional(string, null)

      # (Optional) The ID of the response headers policy (HSTS, X-Frame-Options, ...).
      # Defaults to the AWS managed SecurityHeadersPolicy.
      response_headers_policy_id = optional(string, "67f7725c-6f97-4210-82d7-5512b31e9d03")
    })

    # (Optional) Standard logging v2 to an S3 bucket. The bucket must allow
    # delivery.logs.amazonaws.com to write. Defaults to null.
    log_delivery = optional(object({
      # (Required) ARN of the destination S3 bucket.
      bucket_arn = string

      # (Optional) Fields to deliver. Defaults to null (every field).
      record_fields = optional(list(string))

      # (Optional) "parquet", "json", "plain" or "w3c". Defaults to "parquet".
      output_format = optional(string, "parquet")

      # (Optional) Path appended under the delivery prefix. Defaults to "/{yyyy}/{MM}/{dd}".
      suffix_path = optional(string, "/{yyyy}/{MM}/{dd}")

      # (Optional) Hive-style key=value path segments. Defaults to true.
      enable_hive_compatible_path = optional(bool, true)
    }), null)

    # (Required) The ACM certificate (must be in us-east-1) and minimum TLS version.
    viewer_certificate = object({
      acm_certificate_arn      = string
      minimum_protocol_version = optional(string, "TLSv1.2_2021")
    })
  }))

  default = {}
}
