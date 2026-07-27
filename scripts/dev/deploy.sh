#!/bin/bash
set -euo pipefail

cd /home/ubuntu/order-platform

source scripts/dev/fetch_secrets.sh

echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

export IMAGE_TAG="$1"
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d

echo "Waiting for API to become healthy..."
for i in $(seq 1 15); do
  if curl -f -s http://localhost:4000/health > /dev/null; then
    echo "Healthy on attempt $i."
    bash scripts/dev/update-version.sh "$IMAGE_TAG"
    exit 0
  fi
  echo "Attempt $i failed, retrying in 3s..."
  sleep 3
done

echo "UNHEALTHY after all retries."
exit 1