# ==============================================================================
# modules/stateful_ec2/outputs.tf
#
# Outputs from the Stateful EC2 instance
# ==============================================================================

output "instance_id" {
  description = "The EC2 Instance ID"
  value       = aws_instance.stateful.id
}

output "private_ip" {
  description = "The Private IP address of the EC2 instance hosting Postgres, Redis, and RabbitMQ"
  value       = aws_instance.stateful.private_ip
}

output "security_group_id" {
  description = "The Security Group ID attached to the stateful EC2 instance"
  value       = aws_security_group.stateful_ec2_sg.id
}
