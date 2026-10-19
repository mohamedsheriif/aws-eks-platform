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

variable "ec2_instances" {
  description = "Map of EC2 instance configurations"
  type = map(object({
    # (Required) The AMI ID to use for the instance.
    ami_id = string

    # (Required) The instance type (e.g., t3.micro).
    instance_type = string

    # (Required) The subnet ID to launch the instance in.
    subnet_id = string

    # (Required) A list of security group IDs to associate with the instance.
    security_group_ids = list(string)

    # (Required) Whether to associate a public IP address with the instance.
    associate_public_ip = bool

    # (Required) The user data script to provide when launching the instance.
    user_data = string

    # (Required) The IAM instance profile to attach.
    iam_instance_profile = string

    # (Optional) Whether to enable detailed monitoring. Defaults to false.
    enable_monitoring = optional(bool, false)

    # (Optional) Whether to delete the root volume on instance termination. Defaults to true.
    delete_on_termination = optional(bool, true)

    # (Optional) Source/destination check. Set false for routers. Defaults to true.
    source_dest_check = optional(bool, true)

    # (Optional) The KMS key ARN to use for root volume encryption. Defaults to null (aws/ebs).
    kms_key_id = optional(string, null)
  }))

  default = {}
}
