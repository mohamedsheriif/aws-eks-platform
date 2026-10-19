# Created before the cluster so EKS doesn't create one with unlimited retention.
resource "aws_cloudwatch_log_group" "this" {
  for_each = { for k, v in var.eks_clusters : k => v if length(v.enabled_cluster_log_types) > 0 }

  name              = "/aws/eks/${each.value.name}/cluster"
  retention_in_days = each.value.log_retention_days
  kms_key_id        = each.value.logs_kms_key_arn

  tags = var.tags
}

resource "aws_eks_cluster" "this" {
  for_each = var.eks_clusters

  name                          = each.value.name
  version                       = each.value.version
  role_arn                      = each.value.role_arn
  bootstrap_self_managed_addons = each.value.bootstrap_self_managed_addons
  enabled_cluster_log_types     = each.value.enabled_cluster_log_types

  vpc_config {
    subnet_ids              = each.value.subnet_ids
    security_group_ids      = each.value.security_group_ids
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  # Access is granted only through access entries; the creator gets no implicit admin.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  dynamic "encryption_config" {
    for_each = var.secrets_encryption_kms_key_arn != null ? [var.secrets_encryption_kms_key_arn] : []
    content {
      provider {
        key_arn = encryption_config.value
      }
      resources = ["secrets"]
    }
  }

  tags = merge(
    { Name = format("%s-cluster", each.value.name) },
    each.value.tags,
    var.tags
  )

  lifecycle {
    ignore_changes = [zonal_shift_config]
  }

  depends_on = [aws_cloudwatch_log_group.this]
}

# Karpenter selects the node security group by this tag.
resource "aws_ec2_tag" "karpenter_discovery" {
  for_each = { for k, v in var.eks_clusters : k => v if v.karpenter_discovery }

  resource_id = aws_eks_cluster.this[each.key].vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = each.value.name
}

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name  = aws_eks_cluster.this[each.value.cluster_key].name
  principal_arn = each.value.principal_arn
  type          = each.value.type
}

resource "aws_eks_access_policy_association" "this" {
  for_each = var.access_policy_associations

  cluster_name  = aws_eks_cluster.this[each.value.cluster_key].name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = each.value.access_scope.namespaces
  }

  depends_on = [aws_eks_access_entry.this]
}

resource "aws_eks_pod_identity_association" "this" {
  for_each = var.pod_identity_associations

  cluster_name    = aws_eks_cluster.this[each.value.cluster_key].name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = each.value.role_arn

  tags = var.tags
}
