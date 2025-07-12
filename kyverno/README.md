# Kyverno Policy Engine Deployment with ArgoCD

This directory contains the resources to deploy the Kyverno policy engine and a set of custom security policies. The entire setup is designed to be managed by ArgoCD.

## Prerequisites

-   **ArgoCD:** Must be installed and running in your cluster.
-   **kubectl:** Must be configured to communicate with your cluster.

## Deployment Overview

The deployment is a two-step process:

1.  **Deploy the Kyverno Engine:** First, you apply an ArgoCD `Application` manifest that installs Kyverno from its official Helm chart.
2.  **Deploy Custom Policies:** Second, you create another ArgoCD `Application` to sync the custom policies, RBAC, and gateway configurations from this Git repository.

This separation ensures that the core engine is managed independently from your custom configurations.

--- 

### Step 1: Deploy the Kyverno Engine

The `kyverno-app.yaml` file is a pre-configured ArgoCD `Application` that installs Kyverno using its official Helm chart and a set of recommended values.

Apply this manifest directly to your cluster:
```bash
kubectl apply -f kyverno-app.yaml
```
This will create an `Application` named `kyverno` in the `argocd` namespace. ArgoCD will then deploy Kyverno into the `kyverno` namespace. You can monitor the progress in the ArgoCD UI.

### Step 2: Deploy Custom Policies & Configuration

Once the Kyverno engine is running, deploy your custom policies and configurations.

Create a new ArgoCD `Application` manifest named `kyverno-policies-app.yaml` with the following content. This application will sync the contents of the `policies`, `rbac`, and `gateway-kyverno.yaml` files.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kyverno-policies
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'YOUR_GIT_REPO_URL'  # <-- Replace with your Git repository URL
    path: kyverno
    targetRevision: HEAD
    directory:
      # We only want to sync our custom configs, not the app manifests
      exclude: '{kyverno-app.yaml,helm-values.yaml,README.md}'
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: kyverno
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Replace `YOUR_GIT_REPO_URL` with the URL of your Git repository.**

Apply this manifest to your cluster:
```bash
kubectl apply -f kyverno-policies-app.yaml
```

ArgoCD will create a second `Application` named `kyverno-policies` and apply your custom resources to the cluster.

## Manifests Overview

-   `kyverno-app.yaml`: An ArgoCD `Application` for deploying the core Kyverno engine from its Helm chart.
-   `helm-values.yaml`: A reference file containing Helm values. Note that the primary deployment uses the inline values within `kyverno-app.yaml`.
-   `policies/`: Contains custom Kyverno `ClusterPolicy` resources.
-   `rbac/`: Contains additional RBAC configurations for Kyverno.
-   `gateway-kyverno.yaml`: A `Gateway` resource to expose Kyverno services (e.g., for metrics or a UI).
