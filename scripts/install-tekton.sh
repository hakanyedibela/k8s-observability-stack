#!/usr/bin/env bash
# =============================================================================
# Install Tekton (Pipelines + Triggers + Dashboard) via kubectl apply
# Tekton does not have an official Helm chart — this is the supported method.
# =============================================================================
set -euo pipefail

TEKTON_PIPELINE_VERSION="${TEKTON_PIPELINE_VERSION:-v1.11.0}"
TEKTON_TRIGGERS_VERSION="${TEKTON_TRIGGERS_VERSION:-v0.35.0}"
TEKTON_DASHBOARD_VERSION="${TEKTON_DASHBOARD_VERSION:-v0.67.0}"

echo "=== Installing Tekton Pipelines ${TEKTON_PIPELINE_VERSION} ==="
kubectl apply -f "https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml"
kubectl rollout status deployment/tekton-pipelines-controller -n tekton-pipelines --timeout=300s
kubectl rollout status deployment/tekton-pipelines-webhook -n tekton-pipelines --timeout=300s

echo ""
echo "=== Installing Tekton Triggers ${TEKTON_TRIGGERS_VERSION} ==="
kubectl apply -f "https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml"
kubectl apply -f "https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml"
kubectl rollout status deployment/tekton-triggers-controller -n tekton-pipelines --timeout=300s
kubectl rollout status deployment/tekton-triggers-webhook -n tekton-pipelines --timeout=300s

echo ""
echo "=== Installing Tekton Dashboard ${TEKTON_DASHBOARD_VERSION} ==="
kubectl apply -f "https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml"
kubectl rollout status deployment/tekton-dashboard -n tekton-pipelines --timeout=300s

echo ""
echo "=== Tekton deployed ==="
echo "  Pipelines:  ${TEKTON_PIPELINE_VERSION}"
echo "  Triggers:   ${TEKTON_TRIGGERS_VERSION}"
echo "  Dashboard:  ${TEKTON_DASHBOARD_VERSION}"
echo ""
echo "Access the dashboard:"
echo "  kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines"
