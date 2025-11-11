# Prometheus & Grafana Deployment with ArgoCD

This directory contains the manifests to deploy a monitoring stack consisting of Prometheus and Grafana. The deployment is designed to be managed by ArgoCD.

## Prerequisites

-   **ArgoCD:** Must be installed and running.
-   **Cert-Manager:** Required for issuing TLS certificates for Grafana and Prometheus.
-   **Keycloak (or other OIDC provider):** Required for Grafana OAuth. The manifests are pre-configured to use Keycloak.
-   **Persistent Storage:** A default `StorageClass` must be available for Prometheus data.
-   **StorageClass Configuration:** All PVCs (Prometheus, Alertmanager, Grafana) are configured to use `local-path` storageClass. If using `kube-prometheus-stack`, ensure the Prometheus and Alertmanager CRDs have `storageClassName: local-path` set in their `storage.volumeClaimTemplate.spec` section. See `kube-prometheus-stack-values.yaml` for Helm values override.

## Deployment via ArgoCD

Deployment involves two steps: creating the Grafana OAuth secret and then creating the ArgoCD `Application`.

### 1. Create the Grafana OAuth Secret

Before deploying the application, you must create a secret in the `monitoring` namespace containing the OAuth client ID and secret. This is used to secure Grafana with single sign-on.

**Important:** The `secret.yml` file in this directory is for reference only. Do not apply it directly. Create the secret manually with a secure, unique client secret.

```bash
# Create the monitoring namespace if it doesn't exist
kubectl create namespace monitoring

# Create the secret
kubectl create secret generic grafana-oauth-secret \
  --namespace monitoring \
  --from-literal=OAUTH_CLIENT_ID=grafana \
  --from-literal=OAUTH_CLIENT_SECRET='YOUR_OAUTH_CLIENT_SECRET' # <-- Replace with a strong, unique secret
```

### 2. Create the ArgoCD Application

Create a file named `monitoring-application.yaml` with the following content. This manifest tells ArgoCD to manage the resources in this directory.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'YOUR_GIT_REPO_URL'  # <-- Replace with your Git repository URL
    path: prometheux&grafana       # <-- Note the directory name
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: monitoring
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
kubectl apply -f monitoring-application.yaml
```

## Accessing Services

-   **Grafana:** Accessible at `grafana.your-domain.com`. You will log in via your OIDC provider.
-   **Prometheus:** Accessible at `prometheus.your-domain.com`.

Hostnames are defined in the `Ingress` resources within the manifests.

## Manifests

-   `prometheus_grafana.yaml`: Deploys Prometheus and its related resources (`Service`, `Ingress`, `ConfigMap`, etc.).
-   `grafana-app.yaml`: Deploys Grafana and its `Service`, `Ingress`, and `ConfigMap`.
-   `certificates.yaml`: Contains the `Certificate` resources for securing both Prometheus and Grafana.
-   `secret.yml`: **Reference only.** Contains the structure for the Grafana OAuth secret.
-   `prometheus-crd.yaml`: Prometheus CRD with proper `storageClassName: local-path` configuration.
-   `alertmanager-crd.yaml`: Alertmanager CRD with proper `storageClassName: local-path` configuration.
-   `grafana-pvc.yaml`: Grafana PVC with proper `storageClassName: local-path` configuration.
-   `kube-prometheus-stack-values.yaml`: Helm values override for `kube-prometheus-stack` with proper storageClass settings.
-   `kustomization.yaml`: Kustomize configuration that includes all manifests.

## Troubleshooting

### PVCs Stuck in Pending State

If Prometheus, Alertmanager, or Grafana pods are stuck in `Pending` state due to unbound PVCs:

1. **Check if storageClass is set correctly:**
   ```bash
   kubectl get pvc -n monitoring
   kubectl get prometheus -n monitoring -o yaml | grep storageClassName
   kubectl get alertmanager -n monitoring -o yaml | grep storageClassName
   ```

2. **If storageClassName is empty or missing:**
   - For Prometheus: Patch the CRD to set `storageClassName: local-path`
   - For Alertmanager: Patch the CRD to set `storageClassName: local-path`
   - For Grafana: Ensure the PVC has `storageClassName: local-path` set

3. **Apply the manifests in this directory:**
   ```bash
   kubectl apply -f prometheus-crd.yaml
   kubectl apply -f alertmanager-crd.yaml
   kubectl apply -f grafana-pvc.yaml
   ```

4. **Or use kustomize:**
   ```bash
   kubectl apply -k .
   ```
