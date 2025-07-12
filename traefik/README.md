# Traefik Ingress Controller Deployment with ArgoCD

This directory contains the Kubernetes manifests to deploy Traefik, a modern and powerful cloud-native Ingress Controller. This setup is designed to be deployed and managed by ArgoCD.

## Prerequisites

-   **ArgoCD:** Must be installed and running in your cluster.
-   **Cert-Manager:** Must be installed and configured to issue the TLS certificate for the Traefik dashboard, as defined in `traefik-cert.yaml`.

## Deployment via ArgoCD

To deploy Traefik, you will create an ArgoCD `Application` manifest that points to this directory in your Git repository. ArgoCD will then handle the deployment and lifecycle of the Traefik resources.

### Example ArgoCD Application Manifest

Create a file named `traefik-application.yaml` with the following content:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'YOUR_GIT_REPO_URL'  # <-- Replace with your Git repository URL
    path: traefik
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: traefik
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Replace `YOUR_GIT_REPO_URL` with the URL of your Git repository.**

### Apply the Application Manifest

Apply the manifest to your cluster. ArgoCD will detect it and begin deploying Traefik.

```bash
kubectl apply -f traefik-application.yaml
```

## Accessing the Traefik Dashboard

Once deployed, the Traefik dashboard will be exposed via the `Gateway` resource defined in `traefik-gateway.yaml`. You can access it at the hostname specified in that file (e.g., `traefik.your-domain.com`).

## Manifests

-   `traefik.yaml`: Contains the core Traefik `Deployment`, `Service`, and necessary RBAC (`ClusterRole`, `ClusterRoleBinding`, `ServiceAccount`) resources.
-   `traefik-gateway.yaml`: A `Gateway` resource that exposes the Traefik dashboard service to external traffic.
-   `traefik-cert.yaml`: The `Certificate` resource for securing the Traefik dashboard with a TLS certificate.
