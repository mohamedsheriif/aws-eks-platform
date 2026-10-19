output "release_names" {
  description = "Names of deployed Helm releases"
  value       = { for k, v in helm_release.this : k => v.name }
}

output "release_namespaces" {
  description = "Namespaces of deployed Helm releases"
  value       = { for k, v in helm_release.this : k => v.namespace }
}

output "release_versions" {
  description = "Versions of deployed Helm releases"
  value       = { for k, v in helm_release.this : k => v.version }
}
