resource "helm_release" "this" {
  for_each         = var.releases
  name             = each.value.name
  repository       = each.value.repository
  chart            = each.value.chart
  version          = each.value.version
  namespace        = each.value.namespace
  create_namespace = each.value.create_namespace
  values           = each.value.values
}
resource "kubernetes_manifest" "this" {
  for_each   = var.manifests
  manifest   = jsondecode(each.value)
  depends_on = [helm_release.this]
}
