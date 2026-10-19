output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = { for k, v in aws_instance.this : k => v.id }
}

output "private_ips" {
  description = "Private IP addresses of the EC2 instances"
  value       = { for k, v in aws_instance.this : k => v.private_ip }
}

output "public_ips" {
  description = "Public IP addresses of the EC2 instances"
  value       = { for k, v in aws_instance.this : k => v.public_ip }
}
