# Standard logging v2: CloudFront -> CloudWatch Logs delivery -> S3.
locals {
  log_deliveries = { for k, v in var.cloudfront_distributions : k => v.log_delivery if v.log_delivery != null }
}

resource "aws_cloudwatch_log_delivery_source" "this" {
  for_each = local.log_deliveries

  name         = format("%s-%s-%s-cf-logs", var.project, var.env, each.key)
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.this[each.key].arn

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_destination" "this" {
  for_each = local.log_deliveries

  name          = format("%s-%s-%s-cf-logs-s3", var.project, var.env, each.key)
  output_format = each.value.output_format

  delivery_destination_configuration {
    destination_resource_arn = each.value.bucket_arn
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "this" {
  for_each = local.log_deliveries

  delivery_source_name     = aws_cloudwatch_log_delivery_source.this[each.key].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.this[each.key].arn
  record_fields            = each.value.record_fields

  s3_delivery_configuration {
    suffix_path                 = each.value.suffix_path
    enable_hive_compatible_path = each.value.enable_hive_compatible_path
  }

  tags = var.tags
}
