#!/usr/bin/env bash
# =============================================================================
# Step 4: Deploy kube-prometheus-stack (Prometheus + Alertmanager + Thanos Sidecar)
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "=== Deploying kube-prometheus-stack ==="
helm_deploy prometheus prometheus-community/kube-prometheus-stack 67.4.0 \
  "${VALUES_DIR}/kube-prometheus-stack-values.yaml" 10m

echo ""
echo "=== kube-prometheus-stack deployed ==="
