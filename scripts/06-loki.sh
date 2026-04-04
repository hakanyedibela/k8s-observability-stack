#!/usr/bin/env bash
# =============================================================================
# Step 6: Deploy Loki (log aggregation with S3 backend)
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "=== Deploying Loki ==="
helm_deploy loki grafana/loki 6.24.0 \
  "${VALUES_DIR}/loki-values.yaml" 10m

echo ""
echo "=== Loki deployed ==="
