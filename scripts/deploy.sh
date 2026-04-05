#!/usr/bin/env bash
# =============================================================================
# Deploy Observability Stack via Helm Umbrella Chart
# =============================================================================
# Usage:
#   ./scripts/deploy.sh                     # Deploy core stack
#   ./scripts/deploy.sh --with-argocd       # Deploy core + ArgoCD
#   ./scripts/deploy.sh --with-tekton       # Deploy core + Tekton
#   ./scripts/deploy.sh --with-all          # Deploy everything
#   ./scripts/deploy.sh --from-env          # Generate values from .env
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHART_DIR="$PROJECT_DIR/charts/observability-stack"

# --- Defaults ---
NAMESPACE="${NAMESPACE:-observability}"
RELEASE_NAME="${RELEASE_NAME:-observability}"
WITH_ARGOCD=false
WITH_TEKTON=false
FROM_ENV=false
EXTRA_VALUES_FILES=()

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-argocd)  WITH_ARGOCD=true; shift ;;
    --with-tekton)  WITH_TEKTON=true; shift ;;
    --with-all)     WITH_ARGOCD=true; WITH_TEKTON=true; shift ;;
    --from-env)     FROM_ENV=true; shift ;;
    --namespace|-n) NAMESPACE="$2"; shift 2 ;;
    --values|-f)    EXTRA_VALUES_FILES+=("$2"); shift 2 ;;
    *)              echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "============================================="
echo "  Deploying Observability Stack (Helm)"
echo "============================================="
echo ""
echo "  Namespace:  ${NAMESPACE}"
echo "  Release:    ${RELEASE_NAME}"
echo "  ArgoCD:     ${WITH_ARGOCD}"
echo "  Tekton:     ${WITH_TEKTON}"
echo "  From .env:  ${FROM_ENV}"
echo ""

# =============================================================================
# 1. Create namespace
# =============================================================================
echo "=== Creating namespace: ${NAMESPACE} ==="
kubectl create namespace "${NAMESPACE}" 2>/dev/null || true

# =============================================================================
# 2. Build Helm dependencies
# =============================================================================
echo ""
echo "=== Building Helm dependencies ==="
helm dependency build "$CHART_DIR"

# =============================================================================
# 3. Prepare values arguments
# =============================================================================
VALUES_ARGS=()

# Generate from .env if requested
if [[ "$FROM_ENV" == "true" ]]; then
  echo ""
  echo "=== Generating values from .env ==="
  ENV_VALUES="$(mktemp)"
  chmod 600 "$ENV_VALUES"
  bash "$SCRIPT_DIR/generate-values.sh" > "$ENV_VALUES"
  VALUES_ARGS+=(--values "$ENV_VALUES")
fi

# ArgoCD toggle
if [[ "$WITH_ARGOCD" == "true" ]]; then
  VALUES_ARGS+=(--set "argo-cd.enabled=true")
fi

# Extra values files
for f in "${EXTRA_VALUES_FILES[@]}"; do
  VALUES_ARGS+=(--values "$f")
done

# =============================================================================
# 4. Deploy the umbrella chart
# =============================================================================
echo ""
echo "=== Deploying Helm chart ==="
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  "${VALUES_ARGS[@]}" \
  --wait --timeout 10m

# Clean up temp file
if [[ "$FROM_ENV" == "true" ]] && [[ -n "${ENV_VALUES:-}" ]]; then
  rm -f "$ENV_VALUES"
fi

# =============================================================================
# 5. Tekton (kubectl apply — no Helm chart available)
# =============================================================================
if [[ "$WITH_TEKTON" == "true" ]]; then
  echo ""
  echo "=== Installing Tekton ==="
  bash "$SCRIPT_DIR/install-tekton.sh"
fi

# =============================================================================
# 6. Verify
# =============================================================================
echo ""
echo "=== Verifying deployment ==="
echo ""
echo "Helm releases:"
helm list -n "${NAMESPACE}"
echo ""
echo "Pods:"
kubectl get pods -n "${NAMESPACE}" --sort-by=.metadata.name
echo ""
echo "============================================="
echo "  Observability Stack Deployed Successfully  "
echo "============================================="
echo ""
echo "Access:"
echo "  Grafana:      kubectl port-forward svc/grafana 3000:3000 -n ${NAMESPACE}"
echo "  Prometheus:    kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n ${NAMESPACE}"
echo "  Thanos Query:  kubectl port-forward svc/thanos-query-frontend 9091:9090 -n ${NAMESPACE}"
echo "  Alertmanager:  kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n ${NAMESPACE}"
