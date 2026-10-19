resource "aws_sqs_queue" "this" {
  for_each = var.queues

  name                       = each.value.name
  message_retention_seconds  = each.value.message_retention_seconds
  receive_wait_time_seconds  = each.value.receive_wait_time_seconds
  visibility_timeout_seconds = each.value.visibility_timeout_seconds
  kms_master_key_id          = each.value.kms_master_key_id
  sqs_managed_sse_enabled    = each.value.kms_master_key_id == null ? true : null

  redrive_policy = each.value.dlq_arn != null ? jsonencode({
    deadLetterTargetArn = each.value.dlq_arn
    maxReceiveCount     = each.value.max_receive_count
  }) : null

  tags = merge({
    Name = format("%s-%s-%s-sqs", var.project, var.env, each.key)
  }, var.tags)
}

resource "aws_sqs_queue_policy" "this" {
  for_each = { for k, v in var.queues : k => v if v.policy != null }

  queue_url = aws_sqs_queue.this[each.key].id
  policy    = each.value.policy
}
