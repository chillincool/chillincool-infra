# Bootstrap

Bootstrap configuration for initial cluster setup.
Contains Helmfile definitions and resources for bootstrapping Flux CD and core infrastructure.

## Purpose

This directory is used during the **initial cluster bootstrap process** after Kubernetes is installed (e.g., via Talos, kubeadm, etc.).

## Structure

```
bootstrap/
├── README.md          # This file
├── flux-bootstrap.yaml # Initial GitRepository and Kustomization for Flux
├── mod.just           # Bootstrap orchestration commands (placeholder)
├── resources.yaml.j2  # Initial resources like secrets, namespaces (placeholder)
└── helmfile.d/        # Helmfile configurations for core infrastructure (placeholder)
    ├── 00-crds.yaml   # CRDs bootstrap
    └── 01-apps.yaml   # Core apps bootstrap
```

## Bootstrap Process

1. Install Kubernetes (Talos, kubeadm, etc.)
2. Apply `flux-bootstrap.yaml` to establish GitRepository and root Kustomization
3. Flux automatically discovers and applies `kubernetes/flux/cluster` configuration
4. `kubernetes/flux/cluster` creates HelmRepository and app Kustomizations
5. Apps are deployed from `kubernetes/apps/` directory

## Notes

The bootstrap process runs **ONCE** after cluster creation to install Flux CD and core infrastructure.
After that, Flux takes over via the `kubernetes/flux/cluster` configuration and GitOps workflow.
