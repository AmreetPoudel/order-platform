#!/bin/bash
# Manually triggered — run by hand, via SSH, when a deploy's health check
# has failed and you've decided the fix is to redeploy the last known-good
# version. NOT run automatically by CD.
#
# Redeploys whatever versions.json currently says is "current" — this is
# always the last version that itself passed a health check, since
# update-version.sh only ever writes to versions.json AFTER success.
#
# Usage: bash scripts/dev/rollback.sh

set -euo pipefail

REGION="ap-south-1"
BUCKET="order-platform-tf-state-891274465984"
ENV="dev"
DEPLOY_DIR="/home/ubuntu/order-platform"

cd "$DEPLOY_DIR"

echo "Fetching last known-good version from S3..."
aws s3 cp "s3://$BUCKET/deploy/$ENV/versions.json" /tmp/versions.json --region "$REGION"

CURRENT=$(jq -r '.current' /tmp/versions.json)

if [ "$CURRENT" = "null" ] || [ -z "$CURRENT" ]; then
  echo "No known-good version recorded in versions.json — cannot roll back."
  exit 1
fi

echo "Rolling back to: $CURRENT"

# Need the same secrets any normal deploy needs — DB password, Docker Hub
# credentials — so containers come up correctly.
source scripts/dev/fetch_secrets.sh

echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

export IMAGE_TAG="$CURRENT"
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

echo "Waiting for containers to settle..."
sleep 10

if curl -f http://localhost:4000/health; then
  echo "Rollback successful. Running: $CURRENT"
  # Deliberately NOT calling update-version.sh here — rolling back to an
  # already-recorded "current" isn't a new deploy, so there's nothing new
  # to shift into version history.
else
  echo "Rollback health check ALSO failed."
  echo "This is a serious situation — the last known-good version isn't"
  echo "healthy either. Check application logs and database state directly:"
  echo "  docker compose -f docker-compose.prod.yml logs"
  exit 1
fi