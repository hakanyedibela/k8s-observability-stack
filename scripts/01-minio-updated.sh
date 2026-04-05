#!/usr/bin/env bash

set -euo pipefail

# -------- CONFIG --------
OPERATOR_NS="minio-operator"
TENANT_NS="minio-tenant"
TENANT_NAME="myminio"

ROOT_USER="${ROOT_USER:-admin}"
ROOT_PASSWORD="${ROOT_PASSWORD:-$(openssl rand -base64 12)}"

S3_ACCESS_KEY="${S3_ACCESS_KEY:-appuser}"
S3_SECRET_KEY="${S3_SECRET_KEY:-appsecret123}"

BUCKET_NAME="${BUCKET_NAME:-my-bucket}"
STORAGE_SIZE="${STORAGE_SIZE:-10Gi}"

# -------- FUNCTIONS --------
log() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "$1 not installed"; exit 1; }
}

# -------- CHECKS --------
check_cmd kubectl
check_cmd helm
check_cmd openssl
check_cmd curl

kubectl cluster-info >/dev/null

# -------- INSTALL OPERATOR --------
log "Installing MinIO Operator..."

helm repo add minio https://operator.min.io/ >/dev/null 2>&1 || true
helm repo update >/dev/null

helm upgrade --install minio-operator minio/operator \
  --namespace "$OPERATOR_NS" \
  --create-namespace \
  --wait

# -------- NAMESPACE --------
kubectl get ns "$TENANT_NS" >/dev/null 2>&1 || kubectl create ns "$TENANT_NS"

# -------- CREATE USER SECRET (NEW API) --------
log "Creating root credentials secret..."

kubectl -n "$TENANT_NS" create secret generic minio-user \
  --from-literal=CONSOLE_ACCESS_KEY="$ROOT_USER" \
  --from-literal=CONSOLE_SECRET_KEY="$ROOT_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# -------- CREATE TENANT --------
log "Creating MinIO tenant..."

cat <<EOF | kubectl apply -f -
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: $TENANT_NAME
  namespace: $TENANT_NS
spec:
  pools:
    - name: pool-0
      servers: 1
      volumesPerServer: 1
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: $STORAGE_SIZE

  mountPath: /export
  requestAutoCert: false

  users:
    - name: minio-user
EOF

# -------- WAIT --------
log "Waiting for tenant pods..."
kubectl wait --for=condition=ready pod \
  -l v1.min.io/tenant=$TENANT_NAME \
  -n "$TENANT_NS" \
  --timeout=600s

# -------- PORT FORWARD --------
log "Starting port-forward..."
kubectl port-forward svc/${TENANT_NAME}-console -n "$TENANT_NS" 9090:9090 >/dev/null 2>&1 &
PF_PID=$!

kubectl port-forward svc/${TENANT_NAME}-hl -n "$TENANT_NS" 9000:9000 >/dev/null 2>&1 &
PF_API_PID=$!

sleep 5

# -------- INSTALL MC --------
if ! command -v mc >/dev/null 2>&1; then
  log "Installing mc..."
  curl -s https://dl.min.io/client/mc/release/linux-amd64/mc -o /tmp/mc
  chmod +x /tmp/mc
  sudo mv /tmp/mc /usr/local/bin/mc
fi

# -------- CONFIGURE MC --------
log "Configuring mc..."
mc alias set local http://127.0.0.1:9000 "$ROOT_USER" "$ROOT_PASSWORD"

# -------- CREATE S3 USER --------
log "Creating S3 user..."
mc admin user add local "$S3_ACCESS_KEY" "$S3_SECRET_KEY"
mc admin policy attach local readwrite --user "$S3_ACCESS_KEY"

# -------- CREATE BUCKET --------
log "Creating bucket..."
mc mb local/"$BUCKET_NAME" || true

# -------- CLEANUP --------
kill $PF_PID $PF_API_PID

# -------- OUTPUT --------
echo ""
echo "✅ MinIO READY"
echo ""
echo "Console: http://localhost:9090"
echo ""
echo "Admin:"
echo "  $ROOT_USER / $ROOT_PASSWORD"
echo ""
echo "S3 User:"
echo "  $S3_ACCESS_KEY / $S3_SECRET_KEY"
echo ""
echo "Bucket:"
echo "  $BUCKET_NAME"
echo ""