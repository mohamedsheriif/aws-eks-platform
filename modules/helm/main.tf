resource "helm_release" "this" {
  for_each         = var.releases
  name             = each.value.name
  repository       = each.value.repository
  chart            = each.value.chart
  version          = each.value.version
  namespace        = each.value.namespace
  create_namespace = each.value.create_namespace
  values           = each.value.values
  timeout          = each.value.timeout
}

# kubectl_manifest doesn't contact the cluster at plan time, so manifests whose CRDs
# come from the releases above can be planned on a fresh cluster.
resource "kubectl_manifest" "this" {
  for_each   = var.manifests
  yaml_body  = each.value
  depends_on = [helm_release.this]
}
