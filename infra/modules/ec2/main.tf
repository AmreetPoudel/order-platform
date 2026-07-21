resource "aws_instance" "order_platform_ec2" {
  ami                    = var.order_platform_ami_id
  instance_type          = var.order_platform_instance_type
  subnet_id              = var.order_platform_subnet_id
  vpc_security_group_ids = var.order_platform_sg_ids
  key_name               = var.order_platform_key_name

  associate_public_ip_address = false
  iam_instance_profile = var.order_platform_instance_profile

  user_data = templatefile("${path.module}/scripts/user_data.sh.tpl", {
    environment = var.order_platform_environment
  })

  tags = {
    Name = "order_platform_ec2"
  }
}