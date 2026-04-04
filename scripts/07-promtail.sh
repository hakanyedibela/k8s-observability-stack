#!/usr/bin/env bash
# =============================================================================
# Step 7: Deploy Promtail (log shipper — pushes logs to Loki)
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "=== Deploying Promtail ==="
helm_deploy promtail grafana/promtail 6.16.6 \
  "${VALUES_DIR}/promtail-values.yaml" 5m

echo ""
echo "=== Promtail deployed ==="
