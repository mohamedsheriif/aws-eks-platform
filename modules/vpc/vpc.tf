resource "aws_vpc" "this" {
  for_each = var.vpc

  cidr_block           = each.value.cidr_block
  enable_dns_hostnames = each.value.enable_dns_hostnames
  enable_dns_support   = each.value.enable_dns_support

  tags = merge({
    Name = each.value.name },
    var.tags
  )
}

resource "aws_flow_log" "this" {
  for_each = { for k, v in var.vpc : k => v if v.flow_logs_enabled }

  vpc_id               = aws_vpc.this[each.key].id
  log_destination_type = "s3"
  log_destination      = each.value.flow_logs_s3_bucket_arn
  traffic_type         = "ALL"

  tags = merge({
    Name = "${each.value.name}-flow-log" },
    var.tags
  )
}
