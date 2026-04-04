# Tekton + ArgoCD: Complete CI/CD Example

This example demonstrates a full **GitOps CI/CD pipeline** where:
- **Tekton** handles **CI** — clone, test, build image, push to registry, update manifests
- **ArgoCD** handles **CD** — watches the Git repo for manifest changes and syncs to the cluster

## Architecture

```
  Developer          Git Repo              Tekton               Registry         ArgoCD            Cluster
     |                  |                    |                     |                |                 |
     |-- git push ----->|                    |                     |                |                 |
     |                  |-- webhook -------->|                     |                |                 |
     |                  |                    |-- clone repo        |                |                 |
     |                  |                    |-- run tests         |                |                 |
     |                  |                    |-- build image ----->|                |                 |
     |                  |                    |-- push image ------>|                |                 |
     |                  |                    |-- update k8s/       |                |                 |
     |                  |                    |   manifests with    |                |                 |
     |                  |                    |   new image tag     |                |                 |
     |                  |<-- git push -------|   (commit & push)   |                |                 |
     |                  |                    |                     |                |                 |
     |                  |                    |                     |-- poll/watch -->|                 |
     |                  |                    |                     |                |-- sync -------->|
     |                  |                    |                     |                |  (apply k8s/)   |
     |                  |                    |                     |                |                 |
```

### Key Principle: Image Tag Update in Git

Tekton does **not** deploy directly. After building the image, it commits the new image tag
back into the `k8s/` manifests in Git. ArgoCD picks up that commit and deploys it.
This keeps Git as the single source of truth.

## Repository Structure

```
tekton-argocd-demo/
├── app/                          # Sample application
│   ├── main.go                   # Simple HTTP server
│   ├── main_test.go              # Unit tests
│   └── Dockerfile                # Multi-stage build
├── k8s/                          # Kubernetes manifests (ArgoCD watches this)
│   ├── base/                     # Kustomize base
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   └── overlays/
│       ├── dev/                  # Dev environment overlay
│       │   └── kustomization.yaml
│       └── prod/                 # Prod environment overlay
│           └── kustomization.yaml
├── tekton/                       # Tekton CI resources
│   ├── tasks/
│   │   ├── 01-git-clone.yaml          # Clone source repo
│   │   ├── 02-run-tests.yaml          # Run unit tests
│   │   ├── 03-build-push-image.yaml   # Build + push container image (Kaniko)
│   │   └── 04-update-manifests.yaml   # Commit new image tag to k8s/ manifests
│   ├── pipelines/
│   │   └── ci-pipeline.yaml           # Full CI pipeline (chains the tasks)
│   └── triggers/
│       ├── trigger-template.yaml      # Creates PipelineRun from webhook payload
│       ├── trigger-binding.yaml       # Extracts fields from webhook JSON
│       ├── event-listener.yaml        # HTTP endpoint that receives webhooks
│       └── rbac.yaml                  # ServiceAccount + permissions for triggers
├── argocd/                       # ArgoCD Application definitions
│   ├── project.yaml              # ArgoCD AppProject
│   ├── app-dev.yaml              # ArgoCD Application — dev environment
│   └── app-prod.yaml             # ArgoCD Application — prod environment
└── README.md                     # This file
```

## Prerequisites

- Tekton Pipelines, Triggers, and Dashboard installed (`./scripts/10-tekton.sh`)
- ArgoCD installed (`./scripts/11-argocd.sh`)
- A container registry (Docker Hub, Harbor, GitLab Registry, etc.)
- Git repo with webhook support (GitHub, GitLab, Gitea)

## Setup Guide

### Step 1: Create your Git repositories

You need **one** repo containing everything above. In production you might split
the app code and the k8s manifests into separate repos, but a single repo is simpler
to start with.

```bash
# Create a new repo on your Git server, then:
cp -r examples/tekton-argocd-demo/ ~/my-app
cd ~/my-app
git init
git add .
git commit -m "Initial CI/CD setup"
git remote add origin <YOUR_GIT_REPO_URL>
git push -u origin main
```

### Step 2: Create registry credentials

Tekton needs credentials to push images. Create a secret for your registry:

```bash
# Docker Hub
kubectl create secret docker-registry registry-credentials \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<USERNAME> \
  --docker-password=<TOKEN> \
  -n tekton-pipelines

# GitLab Registry
kubectl create secret docker-registry registry-credentials \
  --docker-server=registry.gitlab.com \
  --docker-username=<USERNAME> \
  --docker-password=<DEPLOY_TOKEN> \
  -n tekton-pipelines

# Harbor
kubectl create secret docker-registry registry-credentials \
  --docker-server=harbor.example.com \
  --docker-username=<USERNAME> \
  --docker-password=<PASSWORD> \
  -n tekton-pipelines
```

### Step 3: Create Git credentials (for Tekton to push manifest updates)

```bash
kubectl create secret generic git-credentials \
  --from-literal=username=<GIT_USERNAME> \
  --from-literal=password=<GIT_TOKEN_OR_PASSWORD> \
  -n tekton-pipelines
```

### Step 4: Apply Tekton resources

```bash
# Apply in order
kubectl apply -f tekton/tasks/
kubectl apply -f tekton/triggers/rbac.yaml
kubectl apply -f tekton/pipelines/
kubectl apply -f tekton/triggers/
```

### Step 5: Configure the webhook

Get the EventListener URL:

```bash
# If using NodePort/LoadBalancer:
kubectl get svc el-ci-event-listener -n tekton-pipelines

# If using port-forward for testing:
kubectl port-forward svc/el-ci-event-listener 8080:8080 -n tekton-pipelines
```

In your Git server, add a webhook:
- **URL**: `http://<EVENTLISTENER_IP>:8080`
- **Content type**: `application/json`
- **Events**: Push events
- **Branch filter**: `main` (optional)

### Step 6: Apply ArgoCD Applications

```bash
kubectl apply -f argocd/
```

### Step 7: Test the full flow

```bash
# Make a code change
echo '// trigger build' >> app/main.go
git add . && git commit -m "trigger CI/CD" && git push

# Watch the Tekton pipeline
tkn pipelinerun logs -f -n tekton-pipelines

# Watch ArgoCD sync (after Tekton commits the new image tag)
argocd app get demo-app-dev
```

## Manual Pipeline Run (without webhook)

For testing without a webhook:

```bash
kubectl create -f - <<EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ci-pipeline-manual-
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: ci-pipeline
  params:
    - name: git-url
      value: "<YOUR_GIT_REPO_URL>"
    - name: git-revision
      value: "main"
    - name: image-name
      value: "<REGISTRY>/<USERNAME>/demo-app"
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 1Gi
    - name: git-credentials
      secret:
        secretName: git-credentials
    - name: docker-credentials
      secret:
        secretName: registry-credentials
EOF
```

## Customization

### Change the container registry

Edit `tekton/pipelines/ci-pipeline.yaml` and update the `image-name` default parameter.

### Add more pipeline stages

Add new Task YAMLs in `tekton/tasks/`, then reference them in `tekton/pipelines/ci-pipeline.yaml`.

Common additions:
- **Security scanning**: Trivy, Grype
- **Linting**: golangci-lint, eslint
- **SAST**: Semgrep, SonarQube
- **Notification**: Slack, email

### Multiple environments

The Kustomize overlays (`k8s/overlays/dev/`, `k8s/overlays/prod/`) let ArgoCD
manage multiple environments from the same repo. Promote from dev to prod by
updating the image tag in the prod overlay.
