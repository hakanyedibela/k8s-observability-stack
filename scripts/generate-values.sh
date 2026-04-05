#!/usr/bin/env bash
# =============================================================================
# Generate Helm values override from .env file
# Usage: ./scripts/generate-values.sh > /tmp/overrides.yaml
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  echo "ERROR: .env file not found at $PROJECT_DIR/.env" >&2
  exit 1
fi

set -a
source "$PROJECT_DIR/.env"
set +a

cat <<EOF
# Auto-generated from .env — do not edit manually.
# Regenerate with: ./scripts/generate-values.sh > /tmp/overrides.yaml

global:
  storageClass: ${STORAGE_CLASS}

s3:
  endpoint: "${S3_ENDPOINT}"
  region: ${S3_REGION}
  accessKey: ${S3_ACCESS_KEY}
  secretKey: ${S3_SECRET_KEY}
  insecure: ${S3_INSECURE}
  buckets:
    thanos: ${S3_BUCKET_THANOS}
    lokiChunks: ${S3_BUCKET_LOKI_CHUNKS}
    lokiRuler: ${S3_BUCKET_LOKI_RULER}
    lokiAdmin: ${S3_BUCKET_LOKI_ADMIN}

grafanaDb:
  host: ${GRAFANA_DB_HOST}
  port: ${GRAFANA_DB_PORT}
  name: ${GRAFANA_DB_NAME}
  user: ${GRAFANA_DB_USER}
  password: "${GRAFANA_DB_PASSWORD}"

grafanaAdmin:
  user: ${GRAFANA_ADMIN_USER}
  password: "${GRAFANA_ADMIN_PASSWORD}"

ingress:
  domain: ${INGRESS_DOMAIN}
  className: ${INGRESS_CLASS}
  tls:
    enabled: ${INGRESS_TLS_ENABLED}
    issuer: ${INGRESS_TLS_ISSUER:-letsencrypt-prod}

minio-operator:
  enabled: true

minio-tenant:
  enabled: true
  tenant:
    pools:
      - servers: 4
        name: pool-0
        volumesPerServer: 2
        size: 25Gi
        storageClassName: ${STORAGE_CLASS}
    buckets:
      - name: ${S3_BUCKET_THANOS}
      - name: ${S3_BUCKET_LOKI_CHUNKS}
      - name: ${S3_BUCKET_LOKI_RULER}
      - name: ${S3_BUCKET_LOKI_ADMIN}
    configSecret:
      name: minio-env-config
      accessKey: ${S3_ACCESS_KEY}
      secretKey: ${S3_SECRET_KEY}
  ingress:
    console:
      enabled: true
      ingressClassName: ${INGRESS_CLASS}
      host: minio.${INGRESS_DOMAIN}

postgresql:
  auth:
    username: ${GRAFANA_DB_USER}
    password: "${GRAFANA_DB_PASSWORD}"
    database: ${GRAFANA_DB_NAME}
  primary:
    persistence:
      storageClass: ${STORAGE_CLASS}

kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      storageSpec:
        volumeClaimTemplate:
          spec:
            storageClassName: ${STORAGE_CLASS}
  alertmanager:
    alertmanagerSpec:
      storage:
        volumeClaimTemplate:
          spec:
            storageClassName: ${STORAGE_CLASS}

thanos:
  query:
    dnsDiscovery:
      sidecarsNamespace: ${NAMESPACE}
    stores:
      - dnssrv+_grpc._tcp.thanos-storegateway.${NAMESPACE}.svc.cluster.local
  storegateway:
    persistence:
      storageClass: ${STORAGE_CLASS}
  compactor:
    persistence:
      storageClass: ${STORAGE_CLASS}
  ruler:
    alertmanagers:
      - http://prometheus-kube-prometheus-alertmanager.${NAMESPACE}.svc.cluster.local:9093
    persistence:
      storageClass: ${STORAGE_CLASS}

loki:
  loki:
    storage:
      bucketNames:
        chunks: ${S3_BUCKET_LOKI_CHUNKS}
        ruler: ${S3_BUCKET_LOKI_RULER}
        admin: ${S3_BUCKET_LOKI_ADMIN}
      s3:
        endpoint: "${S3_ENDPOINT}"
        region: ${S3_REGION}
        secretAccessKey: ${S3_SECRET_KEY}
        accessKeyId: ${S3_ACCESS_KEY}
        s3ForcePathStyle: true
        insecure: ${S3_INSECURE}
  write:
    persistence:
      storageClass: ${STORAGE_CLASS}
  backend:
    persistence:
      storageClass: ${STORAGE_CLASS}

promtail:
  config:
    clients:
      - url: http://loki-gateway.${NAMESPACE}.svc.cluster.local/loki/api/v1/push
        tenant_id: ""
        batchwait: 1s
        batchsize: 1048576

grafana:
  grafana.ini:
    server:
      root_url: "http://grafana.${INGRESS_DOMAIN}"
    database:
      host: "${GRAFANA_DB_HOST}:${GRAFANA_DB_PORT}"
      name: ${GRAFANA_DB_NAME}
      user: ${GRAFANA_DB_USER}
      password: "${GRAFANA_DB_PASSWORD}"
    security:
      admin_user: ${GRAFANA_ADMIN_USER}
  ingress:
    ingressClassName: ${INGRESS_CLASS}
    hosts:
      - grafana.${INGRESS_DOMAIN}
EOF
