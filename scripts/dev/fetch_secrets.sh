#!/bin/bash
# Fetches secrets from AWS SSM Parameter Store and exports them as shell
# variables for this session. Must be SOURCED, not executed — running it
# as `bash fetch_secrets.sh` would export into a child process that exits
# immediately, losing every export before docker compose ever sees them.
#
# Usage: source scripts/dev/fetch_secrets.sh

set -euo pipefail

REGION="ap-south-1"

# Batch fetch — one API call for everything under this path, rather than
# one call per parameter. Adding a new secret later needs zero changes here.
RESULT=$(aws ssm get-parameters-by-path \
  --path "/order-platform/" \
  --with-decryption \
  --region "$REGION" \
  --query "Parameters[*].[Name,Value]" \
  --output text)

# Each line: /order-platform/pg-password<TAB>the-actual-value
# basename strips the path down to "pg-password"
# tr converts to PG_PASSWORD (uppercase, hyphens to underscores)
while IFS=$'\t' read -r name value; do
  key=$(basename "$name" | tr '[:lower:]-' '[:upper:]_')
  export "$key"="$value"
done <<< "$RESULT"