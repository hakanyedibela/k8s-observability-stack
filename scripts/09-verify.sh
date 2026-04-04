#!/usr/bin/env bash
# =============================================================================
# Step 9: Verify Observability Stack Deployment
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "=== Observability Stack Health Check ==="
echo ""

PASS=0
FAIL=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  [OK]   $name"
    ((PASS++))
  else
    echo "  [FAIL] $name"
    ((FAIL++))
  fi
}

echo "--- Pods ---"
echo ""
kubectl get pods -n "${NAMESPACE}" -o wide --no-headers | while read -r line; do
  echo "  $line"
done

echo ""
echo "--- Component Checks ---"
echo ""

if [[ "${DEPLOY_MINIO}" == "true" ]]; then
  check "MinIO" "kubectl get deployment -n ${NAMESPACE} minio -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
fi

check "PostgreSQL" "kubectl get statefulset -n ${NAMESPACE} grafana-postgres-postgresql -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Prometheus Operator" "kubectl get deployment -n ${NAMESPACE} prometheus-kube-prometheus-operator -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Prometheus" "kubectl get statefulset -n ${NAMESPACE} prometheus-prometheus-kube-prometheus-prometheus -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Alertmanager" "kubectl get statefulset -n ${NAMESPACE} alertmanager-prometheus-kube-prometheus-alertmanager -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Thanos Query" "kubectl get deployment -n ${NAMESPACE} thanos-query -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Thanos Query Frontend" "kubectl get deployment -n ${NAMESPACE} thanos-query-frontend -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Thanos Store Gateway" "kubectl get statefulset -n ${NAMESPACE} thanos-storegateway -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Thanos Compactor" "kubectl get statefulset -n ${NAMESPACE} thanos-compactor -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Loki Write" "kubectl get statefulset -n ${NAMESPACE} loki-write -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Loki Read" "kubectl get deployment -n ${NAMESPACE} loki-read -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Loki Backend" "kubectl get statefulset -n ${NAMESPACE} loki-backend -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Grafana" "kubectl get deployment -n ${NAMESPACE} grafana -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
check "Promtail" "kubectl get daemonset -n ${NAMESPACE} promtail -o jsonpath='{.status.numberReady}' | grep -q '[1-9]'"

echo ""
echo "--- PVCs ---"
kubectl get pvc -n "${NAMESPACE}" --no-headers 2>/dev/null | while read -r line; do
  echo "  $line"
done

echo ""
echo "--- Ingresses ---"
kubectl get ingress -n "${NAMESPACE}" --no-headers 2>/dev/null | while read -r line; do
  echo "  $line"
done

echo ""
echo "--- Services ---"
kubectl get svc -n "${NAMESPACE}" --no-headers 2>/dev/null | while read -r line; do
  echo "  $line"
done

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Some components are not ready. Debug with:"
  echo "  kubectl logs -n ${NAMESPACE} <pod-name> --tail=50"
  echo "  kubectl describe pod -n ${NAMESPACE} <pod-name>"
  exit 1
fi

echo ""
echo "Quick access via port-forward:"
echo "  kubectl port-forward svc/grafana 3000:3000 -n ${NAMESPACE}"
echo "  kubectl port-forward svc/thanos-query-frontend 9090:9090 -n ${NAMESPACE}"
echo "  kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9091:9090 -n ${NAMESPACE}"
