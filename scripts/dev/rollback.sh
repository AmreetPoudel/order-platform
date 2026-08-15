#!/bin/bash
# ==============================================================================
# scripts/dev/rollback.sh
#
# Usage: bash scripts/dev/rollback.sh
#
# Reads the 'previous' known-good Git SHA from S3 versions.json,
# sets it as 'current', and guides you to run terraform apply.
# ==============================================================================

set -euo pipefail

REGION="ap-south-1"
BUCKET="order-platform-tf-state-891274465984"
ENV="dev"

echo "🔍 Fetching version history from S3..."
aws s3 cp "s3://$BUCKET/deploy/$ENV/versions.json" /tmp/versions.json --region "$REGION"

CURRENT=$(jq -r '.current // "null"' /tmp/versions.json)
PREVIOUS=$(jq -r '.previous // "null"' /tmp/versions.json)
OLDEST=$(jq -r '.oldest // "null"' /tmp/versions.json)

if [ "$PREVIOUS" = "null" ] || [ -z "$PREVIOUS" ]; then
  echo "❌ No previous known-good version found in versions.json. Cannot roll back."
  exit 1
fi

echo "⏪ Rolling back from '$CURRENT' to previous version: '$PREVIOUS'"

# Promote previous to current, oldest to previous
cat <<EOF > /tmp/versions.json
{
  "current": "$PREVIOUS",
  "previous": "$OLDEST",
  "oldest": "null"
}
EOF

aws s3 cp /tmp/versions.json "s3://$BUCKET/deploy/$ENV/versions.json" --region "$REGION"

echo "✅ S3 versions.json updated for rollback:"
cat /tmp/versions.json
echo ""
echo "🚀 Applying rollback to ECS Fargate..."
cd "$(dirname "$0")/../../infra/environments/dev"
terraform apply -auto-approve

echo "🎉 Rollback complete and live on ECS Fargate!"