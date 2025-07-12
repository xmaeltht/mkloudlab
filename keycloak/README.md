# Keycloak Deployment with ArgoCD

This directory contains the Kubernetes manifests to deploy Keycloak, an open-source identity and access management solution. This application is designed to be deployed and managed by ArgoCD.

## Prerequisites

-   **ArgoCD:** Must be installed and running in your cluster.
-   **Cert-Manager:** Must be installed and configured to issue certificates for the `keycloak-cert.yaml`.
-   **Ingress Controller:** An Ingress or Gateway controller (like Contour, Istio, or NGINX Ingress) must be running to handle external traffic, as defined in `keycloak-gateway.yaml`.
-   **Persistent Storage:** Your cluster must have a default `StorageClass` for the database persistent volume claim.

## Deployment via ArgoCD

To deploy Keycloak, create an ArgoCD `Application` manifest that points to this directory in your Git repository. ArgoCD will then sync the manifests and manage the deployment.

### Example ArgoCD Application Manifest

Create a file named `keycloak-application.yaml` with the following content:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'YOUR_GIT_REPO_URL'  # <-- Replace with your Git repository URL
    path: keycloak
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: keycloak
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Replace `YOUR_GIT_REPO_URL` with the URL of your Git repository.**

### Apply the Application Manifest

Apply the manifest to your cluster. ArgoCD will detect it and begin the deployment.

```bash
kubectl apply -f keycloak-application.yaml
```

## Accessing Keycloak

After deployment, Keycloak will be accessible at the hostname specified in `keycloak-gateway.yaml` (e.g., `keycloak.your-domain.com`). The initial admin username and password are set in the `keycloak.yaml` manifest. It is highly recommended to change the password after your first login.

## Manifests

-   `keycloak.yaml`: Contains the `Deployment`, `Service`, and `PersistentVolumeClaim` for the Keycloak instance and its PostgreSQL database.
-   `keycloak-cert.yaml`: The `Certificate` resource for securing the Keycloak ingress with a TLS certificate.
-   `keycloak-gateway.yaml`: The `Gateway` or `Ingress` resource that exposes the Keycloak service to external traffic.
