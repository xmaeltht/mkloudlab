# Cert-Manager Deployment

This guide details how to set up Cert-Manager to automatically provision and manage TLS certificates for services in your Kubernetes cluster. This setup uses Let's Encrypt as the certificate authority and Cloudflare for DNS-01 challenges to verify domain ownership.

## Prerequisites

- A running Kubernetes cluster.
- `kubectl` configured to communicate with your cluster.
- Helm 3 installed.
- A Cloudflare account with an API token that has `Zone:Read` and `DNS:Edit` permissions for the domain you want to secure.

## Deployment Steps

The deployment process involves three main steps: installing Cert-Manager, creating a secret with your Cloudflare API token, and finally, applying the `ClusterIssuer` and `Certificate` manifests.

### 1. Install Cert-Manager

First, add the Jetstack Helm repository and install Cert-Manager with its Custom Resource Definitions (CRDs).

```bash
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install the cert-manager chart
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.5 \
  --set installCRDs=true
```

Verify the installation by checking the pods in the `cert-manager` namespace:

```bash
kubectl get pods --namespace cert-manager
```

You should see three running pods: `cert-manager`, `cert-manager-cainjector`, and `cert-manager-webhook`.

### 2. Create Cloudflare API Token Secret

Cert-Manager needs your Cloudflare API token to solve DNS-01 challenges. Create a Kubernetes secret named `cloudflare-api-token-secret` in the `cert-manager` namespace.

```bash
kubectl create secret generic cloudflare-api-token-secret \
  --namespace cert-manager \
  --from-literal=api-token='YOUR_CLOUDFLARE_API_TOKEN'
```

Replace `YOUR_CLOUDFLARE_API_TOKEN` with your actual Cloudflare API token.

> **Note for Other DNS Providers:** If you are using a different DNS provider (e.g., Route53, Google Cloud DNS), you will need to create a secret with the appropriate credentials for that provider. Refer to the [Cert-Manager documentation](https://cert-manager.io/docs/configuration/acme/dns01/) for provider-specific instructions.

### 3. Apply the ClusterIssuer and Certificate

Once Cert-Manager is running and the secret is in place, you can apply the `cert-manager.yaml` manifest. This will create a `ClusterIssuer` to issue certificates using Let's Encrypt and a `Certificate` resource to secure the ArgoCD domains.

```bash
kubectl apply -f cert-manager.yaml
```

After a few minutes, you can check the status of the certificate:

```bash
kubectl get certificate -n argocd argocd-cert
```

The `READY` column should show `True`.
