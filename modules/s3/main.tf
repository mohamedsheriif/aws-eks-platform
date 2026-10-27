resource "aws_s3_bucket" "this" {
  for_each = var.buckets

  bucket              = each.value.name
  force_destroy       = each.value.force_destroy
  object_lock_enabled = each.value.object_lock_enabled

  tags = merge(
    { Name = format("%s-%s-%s-s3", var.project, var.env, each.key) },
    var.tags,
    each.value.tags
  )
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = var.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in var.buckets : k => v if v.versioning_enabled }

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "this" {
  for_each = { for k, v in var.buckets : k => v if v.object_lock_enabled }

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    default_retention {
      mode = each.value.object_lock_rule.default_retention_mode
      days = each.value.object_lock_rule.default_retention_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    bucket_key_enabled       = each.value.bucket_key_enabled
    blocked_encryption_types = each.value.blocked_encryption_types
    apply_server_side_encryption_by_default {
      sse_algorithm     = each.value.sse_algorithm
      kms_master_key_id = each.value.kms_master_key_id
    }
  }
}

resource "aws_s3_bucket_logging" "this" {
  for_each = { for k, v in var.buckets : k => v if v.enable_logging }

  bucket        = aws_s3_bucket.this[each.key].id
  target_bucket = each.value.target_bucket
  target_prefix = each.value.target_prefix != "" ? each.value.target_prefix : "${aws_s3_bucket.this[each.key].bucket}/logs/"

  depends_on = [aws_s3_bucket_policy.this]
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = { for k, v in var.buckets : k => v if v.lifecycle_enabled }

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    id     = each.value.lifecycle_rule_id
    status = each.value.lifecycle_rule_status

    filter {
      prefix = each.value.lifecycle_prefix
    }

    dynamic "noncurrent_version_expiration" {
      for_each = each.value.noncurrent_days != null ? [each.value.noncurrent_days] : []
      content {
        noncurrent_days = noncurrent_version_expiration.value
      }
    }

    dynamic "transition" {
      for_each = each.value.transitions
      content {
        days          = transition.value.days
        storage_class = transition.value.storage_class
      }
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    dynamic "expiration" {
      for_each = each.value.expiration_days != null ? [each.value.expiration_days] : []
      content {
        days = expiration.value
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  for_each = { for k, v in var.buckets : k => v if v.bucket_policy != null }

  bucket = aws_s3_bucket.this[each.key].id
  policy = each.value.bucket_policy

  depends_on = [aws_s3_bucket_public_access_block.this]
}
