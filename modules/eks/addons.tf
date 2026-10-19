# vpc-cni, kube-proxy and eks-pod-identity-agent must exist before nodes join;
# coredns and the CSI drivers need nodes to become ACTIVE.
resource "aws_eks_addon" "before_compute" {
  for_each = { for k, v in var.addons : k => v if v.before_compute }

  cluster_name         = aws_eks_cluster.this[each.value.cluster_key].name
  addon_name           = each.value.addon_name
  addon_version        = each.value.addon_version
  configuration_values = each.value.configuration_values

  dynamic "pod_identity_association" {
    for_each = each.value.pod_identity_association
    content {
      role_arn        = pod_identity_association.value.role_arn
      service_account = pod_identity_association.value.service_account
    }
  }

  tags = merge(
    { Name = format("%s-%s-%s-addon", var.project, var.env, each.value.addon_name) },
    var.tags
  )
}

resource "aws_eks_addon" "this" {
  for_each = { for k, v in var.addons : k => v if !v.before_compute }

  cluster_name         = aws_eks_cluster.this[each.value.cluster_key].name
  addon_name           = each.value.addon_name
  addon_version        = each.value.addon_version
  configuration_values = each.value.configuration_values

  dynamic "pod_identity_association" {
    for_each = each.value.pod_identity_association
    content {
      role_arn        = pod_identity_association.value.role_arn
      service_account = pod_identity_association.value.service_account
    }
  }

  tags = merge(
    { Name = format("%s-%s-%s-addon", var.project, var.env, each.value.addon_name) },
    var.tags
  )

  depends_on = [aws_eks_node_group.this]
}
