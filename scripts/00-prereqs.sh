#!/usr/bin/env bash
# =============================================================================
# Step 0: Prerequisites — namespace, helm repos, Prometheus Operator CRDs
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "=== Adding Helm repositories ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts &
helm repo add grafana https://grafana.github.io/helm-charts &
helm repo add bitnami https://charts.bitnami.com/bitnami &
wait
helm repo update

echo ""
echo "=== Creating namespace: ${NAMESPACE} ==="
kubectl create namespace "${NAMESPACE}" 2>/dev/null || true

echo ""
echo "=== Installing Prometheus Operator CRDs ==="
PROM_CRD_VERSION="67.4.0"
PROM_CRD_BASE="https://raw.githubusercontent.com/prometheus-community/helm-charts/kube-prometheus-stack-${PROM_CRD_VERSION}/charts/kube-prometheus-stack/charts/crds/crds"
for crd in \
  crd-alertmanagerconfigs.yaml \
  crd-alertmanagers.yaml \
  crd-podmonitors.yaml \
  crd-probes.yaml \
  crd-prometheusagents.yaml \
  crd-prometheuses.yaml \
  crd-prometheusrules.yaml \
  crd-scrapeconfigs.yaml \
  crd-servicemonitors.yaml \
  crd-thanosrulers.yaml; do
  kubectl apply --server-side -f "${PROM_CRD_BASE}/${crd}" &
done
wait

echo ""
echo "=== Prerequisites done ==="
