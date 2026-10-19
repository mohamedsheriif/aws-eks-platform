variable "releases" {
  description = "Map of Helm release configurations"
  type = map(object({
    name             = string
    repository       = optional(string, "")
    chart            = string
    version          = optional(string, null)
    namespace        = string
    create_namespace = optional(bool, true)
    values           = optional(list(string), [])
  }))
  default = {}
}

variable "manifests" {
  description = "Map of Kubernetes manifests as JSON"
  type        = map(string)
  default     = {}
}
