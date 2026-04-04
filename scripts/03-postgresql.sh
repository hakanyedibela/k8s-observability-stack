#!/usr/bin/env bash
# =============================================================================
# Step 3: Deploy PostgreSQL for Grafana
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "=== Deploying PostgreSQL for Grafana ==="
helm upgrade --install grafana-postgres bitnami/postgresql \
  --namespace "${NAMESPACE}" \
  --version 16.4.1 \
  --set auth.username="${GRAFANA_DB_USER}" \
  --set auth.password="${GRAFANA_DB_PASSWORD}" \
  --set auth.database="${GRAFANA_DB_NAME}" \
  --set primary.persistence.enabled=true \
  --set primary.persistence.storageClass="${STORAGE_CLASS}" \
  --set primary.persistence.size=10Gi \
  --set primary.resources.requests.cpu=250m \
  --set primary.resources.requests.memory=256Mi \
  --set primary.resources.limits.cpu=500m \
  --set primary.resources.limits.memory=512Mi \
  --set primary.podSecurityContext.enabled=true \
  --set primary.containerSecurityContext.enabled=true \
  --set primary.containerSecurityContext.allowPrivilegeEscalation=false \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled=true \
  --wait --timeout 5m

echo ""
echo "=== PostgreSQL deployed ==="
