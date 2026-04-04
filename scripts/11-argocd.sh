#!/usr/bin/env bash
# =============================================================================
# Deploy ArgoCD via Helm
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VALUES_DIR="$PROJECT_DIR/helm-values"

if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-9.4.17}"

# =============================================================================
# 1. Helm repo
# =============================================================================
echo "=== Adding ArgoCD Helm repo ==="
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# =============================================================================
# 2. Namespace
# =============================================================================
echo ""
echo "=== Creating namespace: ${ARGOCD_NAMESPACE} ==="
kubectl create namespace "${ARGOCD_NAMESPACE}" 2>/dev/null || true

# =============================================================================
# 3. Deploy ArgoCD
# =============================================================================
echo ""
echo "=== Deploying ArgoCD ${ARGOCD_CHART_VERSION} ==="

ARGOCD_VALUES="${VALUES_DIR}/argocd-values.yaml"

if [[ -f "$ARGOCD_VALUES" ]]; then
  rendered="$(mktemp)"
  chmod 600 "$rendered"
  envsubst < "$ARGOCD_VALUES" > "$rendered"

  helm upgrade --install argocd argo/argo-cd \
    --namespace "${ARGOCD_NAMESPACE}" \
    --version "${ARGOCD_CHART_VERSION}" \
    --values "$rendered" \
    --wait --timeout 5m

  rm -f "$rendered"
else
  helm upgrade --install argocd argo/argo-cd \
    --namespace "${ARGOCD_NAMESPACE}" \
    --version "${ARGOCD_CHART_VERSION}" \
    --set server.service.type=ClusterIP \
    --set dex.enabled=false \
    --set notifications.enabled=false \
    --set applicationSet.enabled=true \
    --set server.resources.requests.cpu=250m \
    --set server.resources.requests.memory=256Mi \
    --set server.resources.limits.cpu=500m \
    --set server.resources.limits.memory=512Mi \
    --set controller.resources.requests.cpu=500m \
    --set controller.resources.requests.memory=512Mi \
    --set controller.resources.limits.cpu="1" \
    --set controller.resources.limits.memory=1Gi \
    --set repoServer.resources.requests.cpu=250m \
    --set repoServer.resources.requests.memory=256Mi \
    --set repoServer.resources.limits.cpu=500m \
    --set repoServer.resources.limits.memory=512Mi \
    --wait --timeout 5m
fi

# =============================================================================
# 4. Get initial admin password
# =============================================================================
echo ""
echo "=== ArgoCD deployed ==="
echo ""
echo "Initial admin password:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo ""
echo "Access the UI:"
echo "  kubectl port-forward svc/argocd-server 8080:443 -n ${ARGOCD_NAMESPACE}"
echo "  Open: https://localhost:8080"
echo "  User: admin"
echo ""
echo "CLI login:"
echo "  argocd login localhost:8080 --insecure --username admin --password \$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
