output "kms_key_ids" {
  description = "Map of KMS key ids"
  value = {
    for k, v in aws_kms_key.this : k => v.id
  }
}
output "kms_key_arns" {
  description = "Map of KMS key ARNs"
  value = {
    for k, v in aws_kms_key.this : k => v.arn
  }
}