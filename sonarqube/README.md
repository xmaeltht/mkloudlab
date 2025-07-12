# SonarQube Deployment with ArgoCD

This directory contains the Kubernetes manifests required to deploy SonarQube. This application is designed to be deployed and managed by ArgoCD.

## Prerequisites

-   **ArgoCD:** Must be installed and running in your cluster.
-   **Cert-Manager:** Must be installed and configured to issue certificates. The included `sonar-cert.yaml` depends on it.
-   **Persistent Storage:** Your cluster must have a default `StorageClass` available for persistent volume claims.

## Deployment via ArgoCD

To deploy SonarQube, you will create an ArgoCD `Application` manifest that points to this directory in your Git repository. ArgoCD will then automatically sync the manifests and deploy SonarQube.

### Example ArgoCD Application Manifest

Create a file named `sonarqube-application.yaml` with the following content:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sonarqube
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'YOUR_GIT_REPO_URL'  # <-- Replace with your Git repository URL
    path: sonarqube
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: sonarqube
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Replace `YOUR_GIT_REPO_URL` with the URL of your Git repository.**

### Apply the Application Manifest

Apply the manifest to your cluster. ArgoCD will detect it and start the deployment process.

```bash
kubectl apply -f sonarqube-application.yaml
```

## Accessing SonarQube

Once deployed, SonarQube will be accessible at the hostname specified in the `sonar-cert.yaml` and the Ingress object within `sonar.yaml` (e.g., `sonarqube.your-domain.com`).

## Manifests

-   `sonar.yaml`: Contains the `Deployment`, `Service`, `PersistentVolumeClaim`, and `Ingress` for SonarQube.
-   `sonar-cert.yaml`: Contains the `Certificate` resource for securing the SonarQube ingress with TLS.
