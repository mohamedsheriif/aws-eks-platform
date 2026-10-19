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

variable "secrets_encryption_kms_key_arn" {
  description = "(Optional) KMS key ARN used for envelope encryption of Kubernetes Secrets. Defaults to null."
  type        = string
  default     = null
}

variable "eks_clusters" {
  description = "Map of EKS cluster configurations. The API endpoint is private only and access uses access entries."
  type = map(object({
    # (Required) The name of the EKS cluster.
    name = string
    # (Required) The Kubernetes version for the cluster.
    version = string
    # (Required) The ARN of the IAM role for the EKS cluster.
    role_arn = string
    # (Required) List of subnet IDs for the cluster.
    subnet_ids = list(string)
    # (Optional) Whether to bootstrap self-managed add-ons. Defaults to false.
    bootstrap_self_managed_addons = optional(bool, false)
    # (Optional) Additional security group IDs for the cluster. Defaults to [].
    security_group_ids = optional(list(string), [])
    # (Optional) Control plane log types to enable; [] turns logging off. Defaults to [].
    enabled_cluster_log_types = optional(list(string), [])
    # (Optional) Retention in days for the control plane log group. Defaults to 90.
    log_retention_days = optional(number, 90)
    # (Optional) KMS key ARN for the control plane log group. Defaults to null.
    logs_kms_key_arn = optional(string)
    # (Optional) Tag the cluster security group with karpenter.sh/discovery. Defaults to true.
    karpenter_discovery = optional(bool, true)
    # (Optional) Additional tags for the cluster. Defaults to {}.
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "node_groups" {
  description = "Map of EKS managed node groups. Each gets a launch template with IMDSv2 and an encrypted gp3 root volume."
  type = map(object({
    # (Required) Key of the cluster in eks_clusters.
    cluster_key = string
    # (Required) Node group name.
    name = string
    # (Required) IAM role ARN for the nodes.
    node_role_arn = string
    # (Required) Subnets the nodes are launched in.
    subnet_ids = list(string)
    # (Required) Scaling settings.
    desired_size = number
    max_size     = number
    min_size     = number
    # (Required) Instance types for the node group.
    instance_types = list(string)
    # (Optional) ON_DEMAND or SPOT. Defaults to "ON_DEMAND".
    capacity_type = optional(string, "ON_DEMAND")
    # (Optional) AMI type. Defaults to "AL2023_x86_64_STANDARD".
    ami_type = optional(string, "AL2023_x86_64_STANDARD")
    # (Optional) Root volume size in GB. Defaults to 50.
    disk_size = optional(number, 50)
    # (Optional) KMS key ARN for the root volume. Defaults to null (aws/ebs).
    ebs_kms_key_arn = optional(string)
    # (Optional) kubelet maxPods, needed with VPC CNI prefix delegation (e.g. 110). Defaults to null.
    max_pods = optional(number)
    # (Optional) Kubernetes labels. Defaults to {}.
    labels = optional(map(string), {})
    # (Optional) Kubernetes taints. Effect is NO_SCHEDULE, PREFER_NO_SCHEDULE or NO_EXECUTE.
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
  default = {}
}

variable "addons" {
  description = "Map of EKS add-on configurations"
  type = map(object({
    # (Required) Key of the cluster in eks_clusters.
    cluster_key = string
    # (Required) Add-on name (vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, ...).
    addon_name = string
    # (Optional) Install before the node groups (vpc-cni, kube-proxy, eks-pod-identity-agent). Defaults to false.
    before_compute = optional(bool, false)
    # (Optional) Add-on version. Defaults to null (default version for the cluster).
    addon_version = optional(string)
    # (Optional) Add-on configuration as a JSON string. Defaults to null.
    configuration_values = optional(string)
    # (Optional) Pod Identity associations created by the add-on. Defaults to [].
    pod_identity_association = optional(list(object({
      role_arn        = string
      service_account = string
    })), [])
  }))
  default = {}
}

variable "access_entries" {
  description = "Map of EKS access entry configurations"
  type = map(object({
    # (Required) Key of the cluster in eks_clusters.
    cluster_key = string
    # (Required) IAM principal ARN.
    principal_arn = string
    # (Optional) STANDARD, or EC2_LINUX for node roles (e.g. Karpenter nodes). Defaults to "STANDARD".
    type = optional(string, "STANDARD")
  }))
  default = {}
}

variable "access_policy_associations" {
  description = "Map of EKS access policy association configurations (STANDARD entries only)"
  type = map(object({
    # (Required) Key of the cluster in eks_clusters.
    cluster_key = string
    # (Required) IAM principal ARN.
    principal_arn = string
    # (Required) EKS access policy ARN (e.g., arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy).
    policy_arn = string
    # (Required) Access scope: type is "cluster" or "namespace".
    access_scope = object({
      type       = string
      namespaces = optional(list(string), [])
    })
  }))
  default = {}
}

variable "pod_identity_associations" {
  description = "Map of EKS Pod Identity associations binding an IAM role to a service account"
  type = map(object({
    # (Required) Key of the cluster in eks_clusters.
    cluster_key = string
    # (Required) Namespace of the service account.
    namespace = string
    # (Required) Service account name.
    service_account = string
    # (Required) IAM role ARN. Its trust policy must allow pods.eks.amazonaws.com
    # with sts:AssumeRole and sts:TagSession.
    role_arn = string
  }))
  default = {}
}
