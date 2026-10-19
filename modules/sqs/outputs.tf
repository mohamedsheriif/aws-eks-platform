output "queue_arns" {
  description = "Map of queue keys to their ARNs"
  value       = { for k, q in aws_sqs_queue.this : k => q.arn }
}

output "queue_urls" {
  description = "Map of queue keys to their URLs"
  value       = { for k, q in aws_sqs_queue.this : k => q.id }
}

output "queue_names" {
  description = "Map of queue keys to their names"
  value       = { for k, q in aws_sqs_queue.this : k => q.name }
}
