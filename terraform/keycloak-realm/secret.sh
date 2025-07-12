#!/bin/bash

# Create OAuth secrets using tofu (Jenkins now uses SAML, so no secret needed)
GRAFANA_SECRET=$(tofu output -raw grafana_oidc_client_secret)
ARGOCD_SECRET=$(tofu output -raw argocd_oidc_client_secret)
MINIO_SECRET=$(tofu output -raw minio_oidc_client_secret)
PROMETHEUS_SECRET=$(tofu output -raw prometheus_oidc_client_secret)

echo "Creating secrets with OpenTofu outputs..."

# Grafana secret
echo "Creating Grafana OAuth secret..."
kubectl create secret generic grafana-oauth-secret \
  --namespace=monitoring \
  --from-literal=OAUTH_CLIENT_ID=grafana \
  --from-literal=OAUTH_CLIENT_SECRET=$GRAFANA_SECRET \
  --dry-run=client -o yaml | kubectl apply -f -

# ArgoCD secret
echo "Creating ArgoCD OAuth secret..."
kubectl create secret generic argocd-oauth-secret \
  --namespace=argocd \
  --from-literal=OAUTH_CLIENT_ID=argocd \
  --from-literal=OAUTH_CLIENT_SECRET=$ARGOCD_SECRET \
  --dry-run=client -o yaml | kubectl apply -f -

# Jenkins uses SAML now, so no OAuth secret needed
echo "Jenkins uses SAML authentication - no OAuth secret required"

# MinIO secret (create namespace if it doesn't exist)
echo "Creating MinIO OAuth secret..."
kubectl create namespace minio --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic minio-oauth-secret \
  --namespace=minio \
  --from-literal=OAUTH_CLIENT_ID=minio \
  --from-literal=OAUTH_CLIENT_SECRET=$MINIO_SECRET \
  --dry-run=client -o yaml | kubectl apply -f -

# Prometheus secret
echo "Creating Prometheus OAuth secret..."
kubectl create secret generic prometheus-oauth-secret \
  --namespace=monitoring \
  --from-literal=OAUTH_CLIENT_ID=prometheus \
  --from-literal=OAUTH_CLIENT_SECRET=$PROMETHEUS_SECRET \
  --dry-run=client -o yaml | kubectl apply -f -

echo "All secrets created successfully!"

# Verify the Grafana secret
echo -e "\nVerifying Grafana secret:"
kubectl get secret grafana-oauth-secret -n monitoring -o jsonpath='{.data.OAUTH_CLIENT_ID}' | base64 -d
echo ""
echo "Grafana secret created with client ID above."

# Show Jenkins SAML client info
echo -e "\nJenkins SAML client information:"
echo "Client ID: $(tofu output -raw jenkins_saml_client_id)"
echo "Jenkins will authenticate via SAML (no client secret required)"
