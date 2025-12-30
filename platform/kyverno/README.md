# Kyverno Policy Engine Deployment with Flux

This directory contains the resources to deploy the Kyverno policy engine and a set of custom security policies. The entire setup is managed by Flux CD for GitOps operations.

## Prerequisites

-   **Flux CD:** Must be installed and running in your cluster.
-   **kubectl:** Must be configured to communicate with your cluster.

## Deployment Overview

Kyverno is deployed via Flux using HelmReleases and Kustomizations:

1.  **Kyverno Engine:** Deployed via `platform/flux/apps/kyverno.yaml` which installs Kyverno from its official Helm chart.
2.  **Custom Policies:** Deployed via `platform/flux/apps/kyverno-policies.yaml` which syncs the custom policies, RBAC, and gateway configurations from this Git repository.

This separation ensures that the core engine is managed independently from your custom configurations.

## Deployment

Kyverno is automatically deployed when you run:
```bash
task install:apps
```

Or manually:
```bash
kubectl apply -f platform/flux/apps/kyverno.yaml
kubectl apply -f platform/flux/apps/kyverno-policies.yaml
```

You can monitor the progress with:
```bash
flux get helmreleases -n flux-system
flux get kustomizations -n flux-system
```

## Manifests Overview

-   `helm-values.yaml`: Helm values for the Kyverno deployment.
-   `kustomization.yaml`: Kustomization file that includes policies, RBAC, and gateway resources.
-   `policies/`: Contains custom Kyverno `ClusterPolicy` resources.
-   `rbac/`: Contains additional RBAC configurations for Kyverno.
-   `gateway-kyverno.yaml`: A `Gateway` resource to expose Kyverno services (e.g., for metrics or a UI).
