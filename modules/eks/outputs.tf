output "cluster_names" {
  description = "EKS cluster names"
  value       = { for k, v in aws_eks_cluster.this : k => v.name }
}

output "cluster_arns" {
  description = "EKS cluster ARNs"
  value       = { for k, v in aws_eks_cluster.this : k => v.arn }
}

output "cluster_endpoints" {
  description = "EKS cluster API endpoints"
  value       = { for k, v in aws_eks_cluster.this : k => v.endpoint }
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = { for k, v in aws_eks_cluster.this : k => v.certificate_authority[0].data }
}

output "cluster_security_group_ids" {
  description = "Security group EKS creates for the control plane and managed nodes"
  value       = { for k, v in aws_eks_cluster.this : k => v.vpc_config[0].cluster_security_group_id }
}

output "pod_identity_association_ids" {
  description = "Pod Identity association IDs"
  value       = { for k, v in aws_eks_pod_identity_association.this : k => v.association_id }
}

output "node_group_arns" {
  description = "EKS node group ARNs"
  value       = { for k, v in aws_eks_node_group.this : k => v.arn }
}
