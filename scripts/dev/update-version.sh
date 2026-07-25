#!/bin/bash
# Called ONLY after a deploy's health check has passed.
# Shifts the version history (current -> previous -> oldest) and writes
# the updated record to S3 — the single source of truth for "what is the
# last known-good deployment," used by rollback.sh.
#
# Usage: bash scripts/dev/update-version.sh <new_tag>

set -euo pipefail

REGION="ap-south-1"
BUCKET="order-platform-tf-state-891274465984"
ENV="dev"
NEW_TAG="${1:?Usage: update-version.sh <new_tag>}"

# Pull current history from S3. If this is the very first deploy ever,
# the object won't exist yet — fall back to an empty record instead of
# failing the whole deploy over a missing file.
if aws s3 cp "s3://$BUCKET/deploy/$ENV/versions.json" /tmp/versions.json --region "$REGION" 2>/dev/null; then
  CURRENT=$(jq -r '.current' /tmp/versions.json)
  PREVIOUS=$(jq -r '.previous' /tmp/versions.json)
else
  echo "No existing versions.json found — this is the first recorded deploy."
  CURRENT="null"
  PREVIOUS="null"
fi

# Shift the register: oldest drops off, previous becomes oldest,
# current becomes previous, the new tag becomes current.
cat <<EOF > /tmp/versions.json
{
  "current": "$NEW_TAG",
  "previous": "$CURRENT",
  "oldest": "$PREVIOUS"
}
EOF

aws s3 cp /tmp/versions.json "s3://$BUCKET/deploy/$ENV/versions.json" --region "$REGION"

echo "Version history updated:"
cat /tmp/versions.json