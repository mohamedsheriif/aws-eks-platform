output "bucket_names" {
  description = "Names of the created S3 buckets"
  value = {
    for k, bucket in aws_s3_bucket.this :
    k => bucket.bucket
  }
}

output "bucket_arns" {
  description = "ARNs of the created S3 buckets"
  value = {
    for k, bucket in aws_s3_bucket.this :
    k => bucket.arn
  }
}