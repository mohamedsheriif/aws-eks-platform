resource "aws_cloudwatch_event_rule" "this" {
  for_each = var.rules

  name          = each.value.name
  description   = each.value.description
  event_pattern = each.value.event_pattern

  tags = merge({
    Name = format("%s-%s-%s", var.project, var.env, each.key)
  }, var.tags)
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = var.rules

  rule      = aws_cloudwatch_event_rule.this[each.key].name
  target_id = "${each.key}-target"
  arn       = each.value.target_arn
}
