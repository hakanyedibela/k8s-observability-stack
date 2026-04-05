# Kubernetes Observability Stack (RKE2 / kubeadm / k3s)

Production-grade observability stack for vanilla Kubernetes clusters, deployed as a single **Helm umbrella chart**:

- **Prometheus** (via kube-prometheus-stack) - Metrics collection and alerting
- **Thanos** - Long-term metrics storage with S3, global query, and HA
- **Loki** - Log aggregation with S3 backend
- **Promtail** - Log shipping from all nodes
- **Grafana** - Unified dashboards and visualization
- **PostgreSQL** - Grafana database backend
- **MinIO** (optional) - Local S3-compatible storage
- **ArgoCD** (optional) - GitOps continuous delivery
- **Tekton** (optional) - CI/CD pipelines

## Architecture

```
                         Ingress (NGINX)
                    +--------+----------+
                    |     Grafana       |
                    | (Dashboards/UI)   |
                    +--------+----------+
                             |
              +--------------+--------------+
              |                             |
     +--------v--------+          +--------v--------+
     |  Thanos Query   |          |      Loki       |
     |  (Global View)  |          | (Log Aggregation)|
     +--------+--------+          +--------+--------+
              |                             |
     +--------v--------+                   |
     | Thanos Store GW  |                  |
     | Thanos Compactor  |                 |
     +--------+--------+                   |
              |                             |
     +--------v--------+          +--------v--------+
     |   S3 (Metrics)  |          |   S3 (Logs)     |
     +-----------------+          +-----------------+
              ^
              |
     +--------+--------+
     |   Prometheus     |
     | + Thanos Sidecar |
     +-----------------+
```

## Prerequisites

- Kubernetes 1.27+ (RKE2, kubeadm, k3s)
- `kubectl` configured with cluster-admin access
- `helm` v3.12+
- NGINX Ingress Controller (or adjust ingress class)
- S3-compatible object storage (AWS S3, MinIO)
- PostgreSQL database (for Grafana) — or use the bundled one
- cert-manager (optional, for auto TLS)

## Quick Start

### Option 1: Direct Helm install (recommended)

```bash
# 1. Build chart dependencies
helm dependency build ./charts/observability-stack

# 2. Deploy with default values
helm install observability ./charts/observability-stack \
  -n observability --create-namespace

# 3. Or deploy with custom values
helm install observability ./charts/observability-stack \
  -n observability --create-namespace \
  -f my-values.yaml
```

### Option 2: Deploy script with .env file

```bash
# 1. Copy and edit the environment config
cp .env.example .env
vi .env

# 2. Deploy using .env overrides
./scripts/deploy.sh --from-env

# 3. Deploy with optional components
./scripts/deploy.sh --from-env --with-argocd --with-tekton
```

### Option 3: Deploy script without .env

```bash
# Deploy with default values (edit charts/observability-stack/values.yaml first)
./scripts/deploy.sh

# Deploy with extra values file
./scripts/deploy.sh -f values-prod.yaml
```

## Deploy Script Options

```
./scripts/deploy.sh [OPTIONS]

Options:
  --from-env          Generate Helm overrides from .env file
  --with-argocd       Enable ArgoCD deployment
  --with-tekton       Install Tekton Pipelines
  --with-all          Enable ArgoCD + Tekton
  --namespace, -n     Target namespace (default: observability)
  --values, -f        Additional values file(s)
```

## Chart Structure

```
charts/observability-stack/
├── Chart.yaml              # Dependencies (all sub-charts)
├── values.yaml             # Consolidated configuration
└── templates/
    ├── _helpers.tpl        # Template helpers
    ├── secrets.yaml        # Thanos objstore + Grafana admin secrets
    ├── ingress.yaml        # Thanos, Prometheus, Alertmanager ingress
    └── network-policies.yaml
```

### Sub-Charts (Helm Dependencies)

| Component | Chart | Version |
|-----------|-------|---------|
| MinIO Operator | minio/operator | 6.0.4 |
| MinIO Tenant | minio/tenant | 6.0.4 |
| PostgreSQL | bitnami/postgresql | 16.4.1 |
| Prometheus | prometheus-community/kube-prometheus-stack | 67.4.0 |
| Thanos | bitnami/thanos | 15.7.27 |
| Loki | grafana/loki | 6.24.0 |
| Promtail | grafana/promtail | 6.16.6 |
| Grafana | grafana/grafana | 8.8.2 |
| ArgoCD | argo/argo-cd | 9.4.17 |

## Configuration

All configuration is in `charts/observability-stack/values.yaml`. Key sections:

### Top-level settings (used by templates)

```yaml
s3:
  endpoint: "http://10.211.55.28:9000"
  accessKey: minioadmin
  secretKey: minioadmin
  # ...

grafanaDb:
  host: "grafana-postgres-postgresql"
  password: "change-me"

ingress:
  domain: observability.local
  className: nginx
```

### Enable/disable components

```yaml
minio:
  enabled: false        # Set true for local S3

argo-cd:
  enabled: false        # Set true for GitOps

networkPolicies:
  enabled: true

ingressResources:
  enabled: true
```

### Per-environment overrides

Create environment-specific files:

```bash
# values-prod.yaml
helm install observability ./charts/observability-stack \
  -n observability -f values-prod.yaml
```

Or generate overrides from `.env`:

```bash
./scripts/generate-values.sh > /tmp/overrides.yaml
helm install observability ./charts/observability-stack \
  -n observability -f /tmp/overrides.yaml
```

### S3 Buckets Required

| Bucket | Purpose |
|--------|---------|
| `thanos-metrics` | Long-term Prometheus metrics |
| `loki-chunks` | Loki log chunks |
| `loki-ruler` | Loki ruler data |
| `loki-admin` | Loki admin data |

### Storage Classes

| Platform | Default StorageClass |
|----------|---------------------|
| RKE2 | `local-path` |
| kubeadm + Longhorn | `longhorn` |
| kubeadm + NFS | `nfs-client` |
| k3s | `local-path` |
| AWS (EKS/kops) | `gp3` |

## Upgrade

```bash
helm upgrade observability ./charts/observability-stack \
  -n observability -f my-values.yaml
```

## Uninstall

```bash
# Via script (handles Tekton + PVCs + namespace cleanup)
./scripts/uninstall.sh

# Or via Helm directly
helm uninstall observability -n observability
```

## CI/CD Example

See [examples/tekton-argocd-demo/](examples/tekton-argocd-demo/) for a full CI/CD pipeline example using Tekton + ArgoCD.
