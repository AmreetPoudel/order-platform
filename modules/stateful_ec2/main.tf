# ==============================================================================
# modules/stateful_ec2/main.tf
#
# Launches the EC2 instance hosting PostgreSQL, Redis, and RabbitMQ in private subnet.
# Includes IAM role for SSM Session Manager (secure terminal access with zero open ports).
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Fetch Latest Ubuntu AMI if not manually specified
# ------------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------------------------
# 2. IAM Role & Instance Profile for AWS Systems Manager (SSM)
# Allows you to securely access the EC2 terminal from AWS Console / CLI without SSH keys
# ------------------------------------------------------------------------------
resource "aws_iam_role" "stateful_ec2_role" {
  name = "order-platform-stateful-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "order-platform-stateful-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.stateful_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "stateful_ec2_profile" {
  name = "order-platform-stateful-ec2-profile"
  role = aws_iam_role.stateful_ec2_role.name
}

# ------------------------------------------------------------------------------
# 3. EC2 Instance Definition
# ------------------------------------------------------------------------------
resource "aws_instance" "stateful" {
  ami                  = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  subnet_id            = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.stateful_ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.stateful_ec2_profile.name
  key_name             = var.key_name != "" ? var.key_name : null

  # Ensure the instance has a 20GB gp3 root volume for database storage
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = false # Protect data on instance stop/start
    encrypted             = true
    tags = {
      Name = "order-platform-stateful-db-disk"
    }
  }

  # User data: Automated bootstrap script running upon first launch
  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail
              
              # 1. Update and install Docker + Docker Compose
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg lsb-release
              
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              chmod a+r /etc/apt/keyrings/docker.asc
              
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              
              systemctl enable docker
              systemctl start docker
              
              # 2. Setup application directory for stateful compose
              mkdir -p /opt/order-platform-stateful/db
              cd /opt/order-platform-stateful
              
              # Create database init.sql schema
              cat << 'SQL' > /opt/order-platform-stateful/db/init.sql
              CREATE TABLE IF NOT EXISTS posts (
                  id SERIAL PRIMARY KEY,
                  title VARCHAR(255) NOT NULL,
                  content TEXT NOT NULL,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
              );
              SQL

              # 3. Create stateful docker-compose.yml
              cat << 'COMPOSE' > /opt/order-platform-stateful/docker-compose.yml
              services:
                postgres:
                  image: postgres:16-alpine
                  container_name: postgres
                  restart: always
                  environment:
                    POSTGRES_DB: postsdb
                    POSTGRES_USER: postgres
                    POSTGRES_PASSWORD: password123
                  ports:
                    - "5432:5432"
                  volumes:
                    - pgdata:/var/lib/postgresql/data
                    - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
                  healthcheck:
                    test: ["CMD-SHELL", "pg_isready -U postgres"]
                    interval: 5s
                    timeout: 5s
                    retries: 5

                redis:
                  image: redis:7-alpine
                  container_name: redis
                  restart: always
                  ports:
                    - "6379:6379"
                  volumes:
                    - redisdata:/data
                  healthcheck:
                    test: ["CMD", "redis-cli", "ping"]
                    interval: 5s
                    timeout: 5s
                    retries: 5

                rabbitmq:
                  image: rabbitmq:3-management-alpine
                  container_name: rabbitmq
                  restart: always
                  environment:
                    RABBITMQ_DEFAULT_USER: user
                    RABBITMQ_DEFAULT_PASS: password123
                  ports:
                    - "5672:5672"
                    - "15672:15672"
                  volumes:
                    - rabbitmqdata:/var/lib/rabbitmq
                  healthcheck:
                    test: ["CMD", "rabbitmq-diagnostics", "ping"]
                    interval: 10s
                    timeout: 5s
                    retries: 5

              volumes:
                pgdata:
                redisdata:
                rabbitmqdata:
              COMPOSE

              # 4. Start all stateful containers
              docker compose up -d
              EOF

  tags = {
    Name = "order-platform-stateful-ec2"
  }
}
