#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="$1"

cd /home/ubuntu/order-platform
chmod +x scripts/dev/*.sh

source scripts/dev/fetch_secrets.sh
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

export IMAGE_TAG
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d

echo "Waiting for API to become healthy..."
for i in $(seq 1 15); do
  if curl -f -s http://localhost:4000/health > /dev/null; then
    echo "Health check passed on attempt $i."
    HEALTHY=true
    break
  fi
  echo "Attempt $i failed, retrying in 3s..."
  sleep 3
done

if [ "${HEALTHY:-false}" != "true" ]; then
  echo "Health check failed after all retries."
  exit 1
fi

bash scripts/dev/update-version.sh "$IMAGE_TAG"
echo "Deploy succeeded and verified."