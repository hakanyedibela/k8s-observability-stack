#!/usr/bin/env bash
# =============================================================================
# Deploy the full Observability Stack — runs all steps in order.
# You can also run each script individually.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for step in \
  00-prereqs.sh \
  01-minio.sh \
  02-secrets.sh \
  03-postgresql.sh \
  04-prometheus.sh \
  05-thanos.sh \
  06-loki.sh \
  07-promtail.sh \
  08-grafana.sh \
  09-verify.sh; do
  echo ""
  echo ">>>>> Running ${step} <<<<<"
  bash "${SCRIPT_DIR}/${step}"
done

echo ""
echo "============================================="
echo "  Observability Stack Deployed Successfully  "
echo "============================================="
