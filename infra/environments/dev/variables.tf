variable "ssh_ip" {
  type        = string
  description = "Your public IP for SSH ingress, CIDR notation"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 instance, must match provider region ap-south-1"
}