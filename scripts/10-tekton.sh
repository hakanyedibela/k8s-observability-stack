#!/usr/bin/env bash
# =============================================================================
# Deploy Tekton (Pipelines + Triggers + Dashboard)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

TEKTON_PIPELINE_VERSION="${TEKTON_PIPELINE_VERSION:-v1.11.0}"
TEKTON_TRIGGERS_VERSION="${TEKTON_TRIGGERS_VERSION:-v0.35.0}"
TEKTON_DASHBOARD_VERSION="${TEKTON_DASHBOARD_VERSION:-v0.67.0}"

# =============================================================================
# 1. Tekton Pipelines (core)
# =============================================================================
echo "=== Installing Tekton Pipelines ${TEKTON_PIPELINE_VERSION} ==="
kubectl apply -f "https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml"

echo "Waiting for Tekton Pipelines..."
kubectl rollout status deployment/tekton-pipelines-controller -n tekton-pipelines --timeout=300s
kubectl rollout status deployment/tekton-pipelines-webhook -n tekton-pipelines --timeout=300s

# =============================================================================
# 2. Tekton Triggers
# =============================================================================
echo ""
echo "=== Installing Tekton Triggers ${TEKTON_TRIGGERS_VERSION} ==="
kubectl apply -f "https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml"
kubectl apply -f "https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml"

echo "Waiting for Tekton Triggers..."
kubectl rollout status deployment/tekton-triggers-controller -n tekton-pipelines --timeout=300s
kubectl rollout status deployment/tekton-triggers-webhook -n tekton-pipelines --timeout=300s

# =============================================================================
# 3. Tekton Dashboard
# =============================================================================
echo ""
echo "=== Installing Tekton Dashboard ${TEKTON_DASHBOARD_VERSION} ==="
kubectl apply -f "https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml"

echo "Waiting for Tekton Dashboard..."
kubectl rollout status deployment/tekton-dashboard -n tekton-pipelines --timeout=300s

# =============================================================================
# Done
# =============================================================================
echo ""
echo "=== Tekton deployed ==="
echo ""
echo "Components:"
echo "  Pipelines:  ${TEKTON_PIPELINE_VERSION}"
echo "  Triggers:   ${TEKTON_TRIGGERS_VERSION}"
echo "  Dashboard:  ${TEKTON_DASHBOARD_VERSION}"
echo ""
echo "Access the dashboard:"
echo "  kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines"
echo ""
echo "Verify:"
echo "  kubectl get pods -n tekton-pipelines"
