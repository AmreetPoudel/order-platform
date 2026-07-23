variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 instance, must match provider region ap-south-1"
}
variable "ssh_ip" {
  type        = string
  description = "Trusted public IP for SSH ingress, CIDR notation"
}