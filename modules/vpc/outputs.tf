output "vpc_ids" {
  description = "Map of VPC keys to their IDs"
  value       = { for k, v in aws_vpc.this : k => v.id }
}

output "vpc_cidr_blocks" {
  description = "Map of VPC keys to their CIDR blocks"
  value       = { for k, v in aws_vpc.this : k => v.cidr_block }
}

output "subnet_ids" {
  description = "Map of subnet keys to their IDs"
  value       = { for k, v in aws_subnet.this : k => v.id }
}

output "nat_gateway_ips" {
  description = "Map of NAT Gateway keys to their public IPs"
  value       = { for k, v in aws_nat_gateway.this : k => v.public_ip }
}

output "route_table_ids" {
  description = "Map of route table keys to their IDs"
  value       = { for k, v in aws_route_table.this : k => v.id }
}

output "vpc_endpoints" {
  description = "Map of VPC endpoint keys to their details"
  value = {
    for k, v in aws_vpc_endpoint.this : k => {
      id             = v.id
      arn            = v.arn
      prefix_list_id = v.prefix_list_id
    }
  }
}
