# Flux GitOps Migration

This directory contains the Flux configuration that replaces ArgoCD for GitOps operations.

## Migration from ArgoCD to Flux

This repository has been migrated from ArgoCD to Flux. All ArgoCD Application manifests have been converted to Flux Kustomizations and HelmReleases.

## Structure

- `manifests/`: Core Flux installation and GitRepository configuration
- `apps/`: Flux Kustomizations and HelmReleases for all applications

## Installation

1. **Install Flux CLI** (if not already installed):
   ```bash
   curl -s https://fluxcd.io/install.sh | sudo bash
   ```

2. **Install Flux in the cluster**:
   ```bash
   task install:flux
   ```

3. **Configure GitRepository**:
   ```bash
   task flux:configure-repo
   ```

4. **Install all applications**:
   ```bash
   task install:apps
   ```

## Application Types

### Helm Releases
- `cert-manager.yaml` - Cert-Manager Helm chart
- `external-secrets.yaml` - External Secrets Operator
- `sonarqube.yaml` - SonarQube Helm chart
- `loki-stack.yaml` - Loki Stack Helm chart
- `kyverno.yaml` - Kyverno policy engine

### Kustomizations
- `keycloak.yaml` - Keycloak deployment
- `keycloak-gateway.yaml` - Keycloak Gateway API resources
- `sonarqube-gateway.yaml` - SonarQube Gateway API resources
- `monitoring.yaml` - Prometheus & Grafana
- `alloy.yaml` - Grafana Alloy collector
- `tempo.yaml` - Grafana Tempo tracing
- `kyverno-policies.yaml` - Kyverno custom policies
- `security-config.yaml` - Security configurations
- `cluster-config.yaml` - Cluster-wide configurations (ClusterIssuers, etc.)

## Flux Operations

### Check Status
```bash
task flux:status
# Or with Flux CLI:
flux get all -n flux-system
```

### Force Reconciliation
```bash
task flux:sync-all
# Or manually:
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

## Differences from ArgoCD

1. **No Web UI**: Flux doesn't have a built-in web UI like ArgoCD. Use `flux get` commands or kubectl to view status.

2. **Reconciliation**: Flux continuously reconciles resources. No manual sync needed, but you can force reconciliation with `flux reconcile`.

3. **Dependencies**: Use `dependsOn` in Kustomizations/HelmReleases to define dependencies.

4. **Helm Charts**: Helm charts are managed via HelmRepository + HelmRelease resources.

5. **Kustomize**: Directory-based deployments use Kustomization resources pointing to Git paths.

## Troubleshooting

### Check GitRepository Status
```bash
kubectl get gitrepository mkloudlab -n flux-system
kubectl describe gitrepository mkloudlab -n flux-system
```

### Check Kustomization Status
```bash
kubectl get kustomizations -n flux-system
kubectl describe kustomization <name> -n flux-system
```

### Check HelmRelease Status
```bash
kubectl get helmreleases -n flux-system
kubectl describe helmrelease <name> -n flux-system
```

### View Events
```bash
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

## Removing ArgoCD

After confirming Flux is working:

1. Delete ArgoCD applications:
   ```bash
   kubectl delete applications --all -n argocd
   ```

2. Uninstall ArgoCD:
   ```bash
   helm uninstall argocd -n argocd
   kubectl delete namespace argocd
   ```

3. Remove ArgoCD CRDs (optional):
   ```bash
   kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io
   ```

