#!/usr/bin/env bash
# =============================================================================
# Step 2: Create Kubernetes secrets (Thanos objstore + Grafana admin)
# =============================================================================
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "=== Creating secrets ==="

S3_ENDPOINT_CLEAN="${S3_ENDPOINT#http://}"
S3_ENDPOINT_CLEAN="${S3_ENDPOINT_CLEAN#https://}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: thanos-objstore-secret
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  objstore.yml: |
    type: S3
    config:
      bucket: "${S3_BUCKET_THANOS}"
      endpoint: "${S3_ENDPOINT_CLEAN}"
      region: "${S3_REGION}"
      access_key: "${S3_ACCESS_KEY}"
      secret_key: "${S3_SECRET_KEY}"
      insecure: ${S3_INSECURE}
      http_config:
        idle_conn_timeout: 90s
        response_header_timeout: 2m
---
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin-secret
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  admin-user: "${GRAFANA_ADMIN_USER}"
  admin-password: "${GRAFANA_ADMIN_PASSWORD}"
EOF

echo ""
echo "=== Secrets created ==="
