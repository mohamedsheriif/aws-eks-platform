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
    timeout          = optional(number, 300)
  }))
  default = {}
}

variable "manifests" {
  description = "Map of Kubernetes manifests as YAML, applied after all releases"
  type        = map(string)
  default     = {}
}
