#!/usr/bin/env bash
# =============================================================================
# Uninstall the Observability Stack
# =============================================================================
set -euo pipefail

NAMESPACE="${NAMESPACE:-observability}"
RELEASE_NAME="${RELEASE_NAME:-observability}"

echo "============================================="
echo "  Uninstalling Observability Stack"
echo "============================================="
echo ""

# --- Helm release ---
echo "=== Removing Helm release: ${RELEASE_NAME} ==="
helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "  Release not found, skipping."

# --- Tekton (if installed) ---
if kubectl get namespace tekton-pipelines &>/dev/null; then
  echo ""
  echo "=== Removing Tekton ==="
  kubectl delete -f "https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml" 2>/dev/null || true
  kubectl delete -f "https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml" 2>/dev/null || true
  kubectl delete -f "https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml" 2>/dev/null || true
  kubectl delete -f "https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml" 2>/dev/null || true
fi

# --- PVCs ---
echo ""
echo "=== Removing PVCs in ${NAMESPACE} ==="
kubectl delete pvc --all -n "$NAMESPACE" 2>/dev/null || true

# --- Secrets ---
echo ""
echo "=== Removing remaining secrets ==="
kubectl delete secret thanos-objstore-secret grafana-admin-secret -n "$NAMESPACE" 2>/dev/null || true

# --- Namespace ---
echo ""
read -r -p "Delete namespace '${NAMESPACE}'? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  kubectl delete namespace "$NAMESPACE"
  echo "Namespace deleted."
else
  echo "Namespace preserved."
fi

echo ""
echo "============================================="
echo "  Uninstall Complete"
echo "============================================="
