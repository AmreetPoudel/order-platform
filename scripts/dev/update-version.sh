#!/bin/bash
# ==============================================================================
# scripts/dev/update-version.sh
#
# Usage: bash scripts/dev/update-version.sh <new_git_sha>
#
# Updates the 3-version ring buffer (current -> previous -> oldest) in S3:
#   s3://order-platform-tf-state-891274465984/deploy/dev/versions.json
# ==============================================================================

set -euo pipefail

REGION="ap-south-1"
BUCKET="order-platform-tf-state-891274465984"
ENV="dev"
NEW_TAG="${1:?Usage: update-version.sh <new_git_sha>}"

echo "🔄 Fetching current versions.json from S3..."
if aws s3 cp "s3://$BUCKET/deploy/$ENV/versions.json" /tmp/versions.json --region "$REGION" 2>/dev/null; then
  CURRENT=$(jq -r '.current // "null"' /tmp/versions.json)
  PREVIOUS=$(jq -r '.previous // "null"' /tmp/versions.json)
else
  echo "ℹ️ No existing versions.json found in S3 — initializing first record."
  CURRENT="null"
  PREVIOUS="null"
fi

# Rotate versions: oldest dropped, previous becomes oldest, current becomes previous, new becomes current
cat <<EOF > /tmp/versions.json
{
  "current": "$NEW_TAG",
  "previous": "$CURRENT",
  "oldest": "$PREVIOUS"
}
EOF

echo "☁️ Uploading updated versions.json to S3..."
aws s3 cp /tmp/versions.json "s3://$BUCKET/deploy/$ENV/versions.json" --region "$REGION"

echo "✅ Version history updated successfully:"
cat /tmp/versions.json
echo ""
echo "👉 To apply this version to ECS Fargate, run:"
echo "   cd infra/environments/dev && terraform apply -auto-approve"