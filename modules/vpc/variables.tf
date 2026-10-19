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

variable "vpc" {
  description = "Map of VPC configurations"
  type = map(object({
    # (Required) Name tag for the VPC.
    name = string

    # (Required) Whether to create an Internet Gateway for the VPC.
    create_igw = bool

    # (Required) The CIDR block for the VPC (e.g., 10.0.0.0/16).
    cidr_block = string

    # (Optional) Whether to enable DNS hostnames in the VPC. Defaults to true.
    enable_dns_hostnames = optional(bool, true)

    # (Optional) Whether to enable DNS resolution in the VPC. Defaults to true.
    enable_dns_support = optional(bool, true)

    # (Optional) Whether to enable VPC flow logs delivered to S3. Defaults to false.
    flow_logs_enabled = optional(bool, false)

    # (Optional) ARN of the S3 bucket flow logs are delivered to. Required if flow_logs_enabled is true.
    flow_logs_s3_bucket_arn = optional(string, "")
  }))
  default = {}
}

variable "eip" {
  description = "Map of Elastic IPs to create (one per zonal NAT Gateway)"
  type        = map(object({}))
  default     = {}
}

variable "nat" {
  description = "Map of NAT Gateway configurations"
  type = map(object({
    # (Optional) "zonal" (one AZ) or "regional" (spans all AZs). Defaults to "zonal".
    availability_mode = optional(string, "zonal")

    # (Optional) Zonal only: the key of the Elastic IP to use. Defaults to null.
    eip_key = optional(string)

    # (Optional) Zonal only: the key of the public subnet to place the NAT Gateway in. Defaults to null.
    subnet_key = optional(string)

    # (Optional) Regional only: the key of the VPC. Defaults to null.
    vpc_key = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for n in values(var.nat) :
      n.availability_mode == "regional" ? n.vpc_key != null : (n.availability_mode == "zonal" && n.eip_key != null && n.subnet_key != null)
    ])
    error_message = "Zonal NAT Gateways need eip_key and subnet_key; regional ones need vpc_key."
  }
}

variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    # (Required) The key of the VPC to create this subnet in.
    vpc_key = string

    # (Optional) Whether to create a Network ACL for this subnet. Defaults to false (default VPC NACL).
    create_nacl = optional(bool, false)

    # (Required) The Availability Zone for the subnet (e.g., us-east-1a).
    availability_zone = string

    # (Required) The CIDR block for the subnet.
    cidr_block = string

    # (Optional) Whether to auto-assign public IPs to instances in this subnet. Defaults to false.
    map_public_ip_on_launch = optional(bool, false)

    # (Optional) NACL rules applied when create_nacl is true. Set egress = true for outbound rules.
    rules = optional(list(map(any)), [])

    # (Optional) Additional tags for this subnet, e.g. kubernetes.io/role/elb. Defaults to {}.
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "route_tables" {
  description = "Map of route table configurations"
  type = map(object({
    # (Required) The key of the VPC to create this route table in.
    vpc_key = string

    # (Required) List of subnet keys to associate with this route table.
    subnet_keys = list(string)

    # (Optional) Whether to route through the Internet Gateway. Defaults to false.
    use_igw = optional(bool, false)

    # (Optional) Whether to route through a NAT Gateway. Defaults to false.
    use_nat = optional(bool, false)

    # (Optional) The key of the NAT Gateway to route through. Defaults to null.
    nat_key = optional(string, null)

    # (Optional) List of route definitions (e.g., [{cidr_block = "0.0.0.0/0"}]). Defaults to [].
    routes = optional(list(map(any)), [])
  }))
  default = {}
}

variable "vpc_endpoints" {
  description = "Map of Gateway VPC endpoints to create"
  type = map(object({
    # (Required) The key of the VPC to create the endpoint in.
    vpc_key = string

    # (Required) The service name for the endpoint (e.g., com.amazonaws.us-east-1.s3).
    service_name = string

    # (Required) List of route table keys to associate with the endpoint.
    route_table_keys = list(string)

    # (Optional) Endpoint policy in JSON format. Defaults to null (full access).
    policy_json = optional(string, null)
  }))
  default = {}
}
