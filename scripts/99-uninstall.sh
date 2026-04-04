#!/usr/bin/env bash
# =============================================================================
# Uninstall the full Observability Stack
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

set -a
source "$PROJECT_DIR/.env"
set +a

echo "=== Uninstalling Observability Stack from namespace: ${NAMESPACE} ==="
echo ""
read -p "Are you sure? This will delete ALL components and data. (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Removing Helm releases..."
helm uninstall grafana          -n "${NAMESPACE}" 2>/dev/null || true
helm uninstall promtail         -n "${NAMESPACE}" 2>/dev/null || true
helm uninstall loki             -n "${NAMESPACE}" 2>/dev/null || true
helm uninstall thanos           -n "${NAMESPACE}" 2>/dev/null || true
helm uninstall prometheus       -n "${NAMESPACE}" 2>/dev/null || true
helm uninstall grafana-postgres -n "${NAMESPACE}" 2>/dev/null || true
helm uninstall minio            -n "${NAMESPACE}" 2>/dev/null || true

echo ""
echo "Removing secrets..."
kubectl delete secret thanos-objstore-secret grafana-admin-secret -n "${NAMESPACE}" 2>/dev/null || true

echo ""
echo "Removing ingresses..."
kubectl delete ingress --all -n "${NAMESPACE}" 2>/dev/null || true

echo ""
echo "Removing CRDs (Prometheus Operator)..."
read -p "Delete Prometheus Operator CRDs? This affects ALL namespaces. (y/N): " confirm_crds
if [[ "$confirm_crds" == "y" || "$confirm_crds" == "Y" ]]; then
  kubectl get crd -o name | grep -E 'monitoring.coreos.com' | xargs kubectl delete 2>/dev/null || true
fi

echo ""
echo "Removing PVCs..."
read -p "Delete all PVCs in ${NAMESPACE}? This will destroy stored data. (y/N): " confirm_pvc
if [[ "$confirm_pvc" == "y" || "$confirm_pvc" == "Y" ]]; then
  kubectl delete pvc --all -n "${NAMESPACE}" 2>/dev/null || true
fi

echo ""
echo "=== Uninstall complete ==="
echo "NOTE: S3/MinIO bucket data is NOT deleted. Remove it manually if needed."
echo "NOTE: To delete the namespace: kubectl delete namespace ${NAMESPACE}"
