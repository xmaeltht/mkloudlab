# ArgoCD to Flux Migration Guide

This document describes the migration from ArgoCD to Flux for GitOps operations.

## Overview

The repository has been migrated from ArgoCD to Flux. All ArgoCD Application manifests have been converted to Flux resources:

- **Helm Charts** → `HelmRepository` + `HelmRelease`
- **Directory/Kustomize** → `Kustomization`

## What Changed

### Application Definitions

All applications in `platform/argocd/apps/` have been converted to Flux resources in `platform/flux/apps/`:

| ArgoCD Application | Flux Resource | Type |
|-------------------|---------------|------|
| cert-manager-app.yaml | cert-manager.yaml | HelmRelease |
| external-secrets-app.yaml | external-secrets.yaml | HelmRelease |
| sonarqube-app.yaml | sonarqube.yaml | HelmRelease |
| loki-stack-app.yaml | loki-stack.yaml | HelmRelease |
| kyverno-engine-app.yaml | kyverno.yaml | HelmRelease |
| keycloak-app.yaml | keycloak.yaml | Kustomization |
| monitoring-app.yaml | monitoring.yaml | Kustomization |
| alloy-app.yaml | alloy.yaml | Kustomization |
| tempo-app.yaml | tempo.yaml | Kustomization |
| kyverno-policies-app.yaml | kyverno-policies.yaml | Kustomization |
| security-config-app.yaml | security-config.yaml | Kustomization |
| cluster-config-app.yaml | cluster-config.yaml | Kustomization |

### Taskfile Changes

- `install:argocd` → `install:flux`
- `argocd:configure-repo` → `flux:configure-repo`
- `argocd:sync-all` → `flux:sync-all`
- Added `flux:status` for viewing Flux resource status

### Key Differences

1. **No Web UI**: Flux doesn't have a built-in UI. Use CLI commands or kubectl.

2. **Continuous Reconciliation**: Flux automatically reconciles every 5 minutes (configurable).

3. **Dependencies**: Use `dependsOn` in Kustomizations/HelmReleases.

4. **GitRepository**: Single GitRepository resource points to the repository.

## Migration Steps

### 1. Install Flux

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Install Flux in cluster
task install:flux
```

### 2. Configure GitRepository

```bash
task flux:configure-repo
```

### 3. Install Applications

```bash
task install:apps
```

### 4. Verify Status

```bash
task flux:status
# Or:
flux get all -n flux-system
```

### 5. Remove ArgoCD (After Verification)

```bash
# Delete ArgoCD applications
kubectl delete applications --all -n argocd

# Uninstall ArgoCD
helm uninstall argocd -n argocd
kubectl delete namespace argocd

# Remove CRDs (optional)
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io
```

## Common Operations

### View Application Status
```bash
flux get kustomizations -n flux-system
flux get helmreleases -n flux-system
```

### Force Reconciliation
```bash
flux reconcile source git mkloudlab -n flux-system
flux reconcile kustomization <name> -n flux-system
flux reconcile helmrelease <name> -n flux-system
```

### View Logs
```bash
kubectl logs -n flux-system -l app.kubernetes.io/name=source-controller
kubectl logs -n flux-system -l app.kubernetes.io/name=kustomize-controller
kubectl logs -n flux-system -l app.kubernetes.io/name=helm-controller
```

## Troubleshooting

### GitRepository Not Ready
```bash
kubectl describe gitrepository mkloudlab -n flux-system
# Check for authentication issues or network problems
```

### Kustomization Stuck
```bash
kubectl describe kustomization <name> -n flux-system
# Check for dependency issues or resource conflicts
```

### HelmRelease Failed
```bash
kubectl describe helmrelease <name> -n flux-system
# Check Helm chart values and dependencies
```

## Benefits of Flux

1. **Simpler**: Fewer components, easier to understand
2. **Native Kubernetes**: Uses standard Kubernetes APIs
3. **No Web UI Overhead**: Lighter resource footprint
4. **Better for CI/CD**: Designed for GitOps workflows
5. **Helm Native**: Better Helm chart support

## Rollback

If you need to rollback to ArgoCD:

1. Reinstall ArgoCD: `task install:argocd`
2. Re-apply ArgoCD applications from `platform/argocd/apps/`
3. Remove Flux: `kubectl delete namespace flux-system`

