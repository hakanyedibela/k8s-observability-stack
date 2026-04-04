#!/usr/bin/env bash
# =============================================================================
# Shared helpers for the Observability Stack scripts
# Source this file — do not execute directly.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VALUES_DIR="$PROJECT_DIR/helm-values"

# --- Load .env ---
if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi
set -a
source "$PROJECT_DIR/.env"
set +a

# --- helm_deploy: render values template and run helm upgrade --install ---
# Usage: helm_deploy <release> <chart> <version> <values_template> <timeout>
helm_deploy() {
  local release="$1" chart="$2" version="$3" values_template="$4" timeout="$5"
  local rendered
  rendered="$(mktemp)"
  chmod 600 "$rendered"
  trap "rm -f '$rendered'" RETURN

  envsubst < "$values_template" > "$rendered"
  helm upgrade --install "$release" "$chart" \
    --namespace "${NAMESPACE}" \
    --version "$version" \
    --values "$rendered" \
    --wait --timeout "$timeout"
}
