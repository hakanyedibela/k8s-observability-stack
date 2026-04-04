#!/usr/bin/env bash
# =============================================================================
# Step 8: Deploy Grafana (dashboards + visualization)
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "=== Deploying Grafana ==="
helm_deploy grafana grafana/grafana 8.8.2 \
  "${VALUES_DIR}/grafana-values.yaml" 5m

echo ""
echo "=== Grafana deployed ==="
echo ""
echo "Access URLs:"
echo "  Grafana:      http://grafana.${INGRESS_DOMAIN}"
echo "  Thanos:       http://thanos.${INGRESS_DOMAIN}"
echo "  Prometheus:   http://prometheus.${INGRESS_DOMAIN}"
echo "  Alertmanager: http://alertmanager.${INGRESS_DOMAIN}"
if [[ "${DEPLOY_MINIO}" == "true" ]]; then
echo "  MinIO:        http://minio.${INGRESS_DOMAIN}"
fi
echo ""
echo "Or use port-forward:"
echo "  kubectl port-forward svc/grafana 3000:3000 -n ${NAMESPACE}"
echo "  kubectl port-forward svc/thanos-query-frontend 9090:9090 -n ${NAMESPACE}"
