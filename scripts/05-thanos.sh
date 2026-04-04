#!/usr/bin/env bash
# =============================================================================
# Step 5: Deploy Thanos (long-term metrics storage + global query)
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "=== Deploying Thanos ==="
helm_deploy thanos bitnami/thanos 15.7.27 \
  "${VALUES_DIR}/thanos-values.yaml" 10m

echo ""
echo "=== Thanos deployed ==="
