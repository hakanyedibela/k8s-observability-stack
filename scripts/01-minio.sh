#!/usr/bin/env bash
# =============================================================================
# Step 1 (Optional): Deploy MinIO — local S3-compatible storage
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [[ "${DEPLOY_MINIO}" != "true" ]]; then
  echo "DEPLOY_MINIO is not 'true' in .env — skipping MinIO."
  exit 0
fi

echo "=== Deploying MinIO (local S3) ==="
helm_deploy minio bitnami/minio 14.8.5 \
  "${VALUES_DIR}/minio-values.yaml" 5m

echo ""
echo "=== MinIO deployed ==="
