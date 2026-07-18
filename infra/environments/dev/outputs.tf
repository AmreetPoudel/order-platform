output "order_platform_ec2_public_ip" {
  value       = module.elastic_ip.order_platform_public_ip
  description = "Public IP (EIP) to SSH into the order_platform EC2 instance"
}
