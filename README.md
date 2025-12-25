# Chillincool Infrastructure

GitOps-driven Kubernetes cluster configuration using Flux CD and Helm charts from a private GHCR repository.

## Architecture

This repository follows the [onedr0p/home-ops](https://github.com/onedr0p/home-ops) pattern with clear separation of concerns:

```
📁 chillincool-infra/
├── 📁 bootstrap/              # Initial cluster setup (run once)
│   ├── flux-bootstrap.yaml    # GitRepository & root Kustomization for Flux
│   ├── resources.yaml.j2      # Initial secrets/resources (placeholder)
│   └── helmfile.d/            # CRDs and core infrastructure (placeholder)
│
├── 📁 kubernetes/             # All Kubernetes configurations (managed by Flux)
│   ├── 📁 apps/               # Applications organized by namespace
│   │   └── 📁 default/        # Default namespace
│   │       └── 📁 prowlarr/   # Example app (Prowlarr)
│   │           ├── app/       # HelmRelease and supporting resources
│   │           ├── namespace.yaml
│   │           └── kustomization.yaml
│   │
│   └── 📁 flux/               # Flux system configuration
│       └── 📁 cluster/        # Cluster bootstrap resources
│           ├── namespace.yaml
│           ├── helmrepository-chillincool.yaml  # OCI repo reference
│           ├── ks-default-apps.yaml             # App Kustomization
│           └── kustomization.yaml
│
└── README.md
```

## GitOps Workflow

1. **Bootstrap Phase** (run once):

   ```bash
   kubectl apply -f bootstrap/flux-bootstrap.yaml
   ```

   This creates the GitRepository pointing to this repo and a root Kustomization

2. **Flux Discovery**:
   Flux applies `kubernetes/flux/cluster/kustomization.yaml` which:
   - Creates the `chillincool` HelmRepository (pointing to `oci://ghcr.io/chillincool`)
   - Creates Kustomizations for app namespaces (e.g., `default-apps`)

3. **App Deployment**:
   Each app Kustomization points to `kubernetes/apps/`, Flux recursively applies all kustomizations

4. **Example: Prowlarr**:
   - `kubernetes/apps/default/prowlarr/kustomization.yaml` creates namespace
   - References `./app/kustomization.yaml` which includes HelmRelease
   - HelmRelease pulls chart from `oci://ghcr.io/chillincool/prowlarr`

## Adding Applications

To add a new app (e.g., `radarr`):

```bash
mkdir -p kubernetes/apps/default/radarr/{app,resources}
```

Create `kubernetes/apps/default/radarr/app/helmrelease.yaml`:

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: radarr
spec:
  interval: 30m
  chart:
    spec:
      chart: radarr
      sourceRef:
        kind: HelmRepository
        name: chillincool
        namespace: flux-system
  values: {}
```

Create `kubernetes/apps/default/radarr/kustomization.yaml`:

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: default
resources:
  - ./namespace.yaml
  - ./app/kustomization.yaml
```

Update `kubernetes/apps/default/kustomization.yaml`:

```yaml
resources:
  - ./prowlarr/kustomization.yaml
  - ./radarr/kustomization.yaml # Add this
```

Commit and push - Flux will automatically deploy it!

## Current Applications

- **prowlarr**: Indexer aggregator from GHCR (test deployment)

## Prerequisites

- Kubernetes cluster with Flux v2 bootstrapped
- Access to `ghcr.io/chillincool` OCI repository
- `kubectl` configured

## Key Differences from Talos/onedr0p Setup

This simplified setup focuses **only on app deployments**:

- ❌ No `talos/` directory (OS-level configuration)
- ❌ No `ansible/` directory (infrastructure provisioning)
- ❌ No `.justfile` orchestration (minimal setup)

Focus is purely on: **GitOps app deployments via Flux + Helm from GHCR**

## Useful Commands

```bash
# Check Flux status
flux check

# View HelmReleases
kubectl get helmrelease -A

# View Kustomizations
kubectl get kustomization -A

# View reconciliation events
flux logs --all-namespaces --follow

# Force reconcile specific HelmRelease
flux reconcile helmrelease prowlarr -n default

# Sync all Kustomizations
flux reconcile kustomization flux-cluster -n flux-system --with-source
```

## References

- [Flux CD Documentation](https://fluxcd.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Helm OCI Registries](https://helm.sh/docs/topics/registries/)
- [Reference: onedr0p/home-ops](https://github.com/onedr0p/home-ops)
