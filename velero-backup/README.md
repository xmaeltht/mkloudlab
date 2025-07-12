# Velero & MinIO Deployment with ArgoCD

This directory contains the manifests to deploy Velero for cluster backups and MinIO as the S3-compatible storage backend. This setup is designed to be managed by ArgoCD.

## Prerequisites

-   **ArgoCD:** Must be installed and running.
-   **Cert-Manager:** Required for issuing the TLS certificate for the MinIO gateway.
-   **Ingress Controller:** An Ingress or Gateway controller is needed to expose the MinIO service.

## Deployment via ArgoCD

Deployment is a two-step process: first, create the secret containing the MinIO credentials for Velero, and second, create the ArgoCD `Application` to deploy both MinIO and Velero.

### 1. Create the Velero S3 Credentials Secret

Velero needs credentials to access the MinIO object storage. The `minio.yaml` manifest sets the default MinIO root user and password. You will use these credentials to create a secret for Velero.

**Note:** The default credentials in `minio.yaml` are `minio` / `minio123`. It is strongly recommended to change these in the manifest before deployment.

Create a file named `velero-s3-credentials` with the following content:

```ini
[default]
aws_access_key_id = minio
aws_secret_access_key = minio123
```

Now, create the Kubernetes secret from this file in the `velero` namespace.

```bash
# Create the velero namespace if it doesn't exist
kubectl create namespace velero

# Create the secret
kubectl create secret generic velero-s3-credentials \
  --namespace velero \
  --from-file=cloud=./velero-s3-credentials
```

### 2. Create the ArgoCD Application

Create a file named `backup-application.yaml` with the following content. This manifest tells ArgoCD to deploy both MinIO and Velero.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: velero-minio
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'YOUR_GIT_REPO_URL'  # <-- Replace with your Git repository URL
    path: velero-backup
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: velero # Both will be deployed here
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Replace `YOUR_GIT_REPO_URL` with your repository URL.**

Apply the manifest:
```bash
kubectl apply -f backup-application.yaml
```

ArgoCD will deploy MinIO first, followed by Velero. You should verify that the MinIO pod is running and healthy before expecting Velero to function correctly.

## Accessing MinIO

MinIO will be accessible at the hostname defined in `minio-gateway-http.yaml` (e.g., `minio.your-domain.com`). You can use this interface to browse your backups.

## Manifests

-   `minio.yaml`: Deploys the MinIO stateful set and service.
-   `minio-gateway-http.yaml`: Exposes the MinIO service via an HTTP Gateway.
-   `velero.yaml`: Deploys Velero, configured to use MinIO as the backup storage location.
-   `velero-cert.yaml`: Contains the `Certificate` resource for securing the MinIO gateway.
