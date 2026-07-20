#!/bin/bash
set -euxo pipefail

echo "Deploying environment: ${environment}"

apt-get update -y
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu
newgrp docker
