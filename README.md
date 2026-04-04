# Kubernetes Observability Stack (RKE2 / kubeadm / k3s)

Production-grade observability stack for vanilla Kubernetes clusters:
- **Prometheus** (via kube-prometheus-stack) - Metrics collection and alerting
- **Thanos** - Long-term metrics storage with S3, global query, and HA
- **Loki** - Log aggregation with S3 backend
- **Grafana** - Unified dashboards and visualization
- **NGINX Ingress** - TLS-terminated ingress for all UIs

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

### For local development with MinIO

If you don't have S3, step 01 can optionally install MinIO for you.

## Quick Start

```bash
# 1. Copy and edit the environment config
cp .env.example .env
vi .env

# 2. Deploy everything at once
./scripts/deploy-all.sh

# 3. Verify
./scripts/09-verify.sh
```

## Step-by-Step Deployment

Each component can be deployed independently in dependency order:

| Script | Component | Depends on |
|--------|-----------|------------|
| `00-prereqs.sh` | Namespace, Helm repos, Prometheus CRDs | — |
| `01-minio.sh` | MinIO (optional local S3) | 00 |
| `02-secrets.sh` | Thanos + Grafana secrets | 00 |
| `03-postgresql.sh` | PostgreSQL (Grafana DB) | 00 |
| `04-prometheus.sh` | kube-prometheus-stack | 00, 02 (thanos secret) |
| `05-thanos.sh` | Thanos | 00, 02, 04 |
| `06-loki.sh` | Loki | 00, 01 or external S3 |
| `07-promtail.sh` | Promtail | 00, 06 |
| `08-grafana.sh` | Grafana | 00, 02, 03, 04, 05, 06 |
| `09-verify.sh` | Health check | all above |

Example — deploy only Prometheus and Thanos (assuming you already have S3):

```bash
./scripts/00-prereqs.sh
./scripts/02-secrets.sh
./scripts/04-prometheus.sh
./scripts/05-thanos.sh
```

## Configuration

All sensitive values are managed via `.env` file (never committed).
Helm values are in `helm-values/` — adjust resource limits, storage classes, replicas.

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

Set `STORAGE_CLASS` in `.env` to match your cluster.

## Uninstall

```bash
./scripts/99-uninstall.sh
```
