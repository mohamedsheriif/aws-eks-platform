variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "zones" {
  description = "Map of public hosted zones to create"
  type = map(object({
    # (Required) The domain the zone serves, e.g. "dev.shopflow.example.com".
    name = string

    # (Optional) Comment shown in the Route 53 console. Defaults to "Managed by Terraform".
    comment = optional(string, "Managed by Terraform")

    # (Optional) Delete all records on destroy instead of failing. Defaults to false.
    force_destroy = optional(bool, false)
  }))
  default = {}
}
