#!/bin/bash
set -euo pipefail

REGION="ap-south-1"

read -sp "Postgres password: " PG_PASSWORD; echo
read -sp "Docker Hub token: " DOCKERHUB_TOKEN; echo
read -p "Docker Hub username: " DOCKERHUB_USERNAME

aws ssm put-parameter --name "/order-platform/pg-password" --value "$PG_PASSWORD" --type SecureString --region "$REGION" --overwrite
aws ssm put-parameter --name "/order-platform/dockerhub-token" --value "$DOCKERHUB_TOKEN" --type SecureString --region "$REGION" --overwrite
aws ssm put-parameter --name "/order-platform/dockerhub-username" --value "$DOCKERHUB_USERNAME" --type SecureString --region "$REGION" --overwrite

echo "Done. Verify with:aws ssm describe-parameters --region $REGION --parameter-filters Key=Name,Option=BeginsWith,Values=/order-platform"