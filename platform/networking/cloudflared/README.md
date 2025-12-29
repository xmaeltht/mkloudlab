# Cloudflare Tunnel Configuration

This directory contains the Cloudflare Tunnel setup for exposing public applications.

## Current Setup

- **Tunnel Name**: mkloudlab
- **Tunnel ID**: `45f7a119-3bfc-4494-88e6-dd783b1bf4b0`
- **Public Apps**: Keycloak (keycloak.maelkloud.com)
- **Private Apps** (via Tailscale): Grafana, Prometheus, Loki, Tempo, Alloy

## Deployment

The tunnel is deployed via raw Kubernetes manifests (not Flux) due to secret management.

### Prerequisites

1. Cloudflare account with Zero Trust enabled
2. Tunnel credentials JSON file at `~/.cloudflared/45f7a119-3bfc-4494-88e6-dd783b1bf4b0.json`
3. DNS CNAME record: `keycloak.maelkloud.com` → `45f7a119-3bfc-4494-88e6-dd783b1bf4b0.cfargotunnel.com`

### Manual Steps Required

**IMPORTANT**: The tunnel ingress routes MUST be configured in the Cloudflare Zero Trust Dashboard:

1. Go to https://one.dash.cloudflare.com/
2. Navigate to **Networks** → **Tunnels**
3. Click on **mkloudlab** tunnel
4. Click **Configure** (or look for configuration/routes section)
5. Add Public Hostname:
   - Subdomain: `keycloak`
   - Domain: `maelkloud.com`
   - Service Type: `HTTP`
   - URL: `10.98.195.252:80` (main-gateway-istio ClusterIP)
   - Additional settings:
     - HTTP Host Header: `keycloak.maelkloud.com`
     - No TLS Verify: Enabled

### Files

- `namespace.yaml`: Cloudflared namespace
- `configmap.yaml`: Tunnel configuration (local config - may be overridden by dashboard)
- `secret.yaml`: Tunnel credentials (gitignored - create manually)
- `deployment.yaml`: Cloudflared deployment

### Creating the Secret

```bash
kubectl create secret generic cloudflared-credentials \
  --from-file=credentials.json=~/.cloudflared/45f7a119-3bfc-4494-88e6-dd783b1bf4b0.json \
  -n cloudflared
```

### Applying Manifests

```bash
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
# Create secret manually (see above)
kubectl apply -f deployment.yaml
```

## Troubleshooting

### HTTP 530 Error

If you get HTTP 530 when accessing keycloak.maelkloud.com:
1. Check tunnel is connected: `kubectl logs -n cloudflared deployment/cloudflared`
2. Verify public hostname is configured in Cloudflare dashboard (see Manual Steps above)
3. Check DNS: `dig keycloak.maelkloud.com CNAME +short` should return tunnel CNAME
4. Test gateway directly: `curl -H "Host: keycloak.maelkloud.com" http://10.98.195.252`

### Tunnel Not Connecting

1. Check credentials secret exists: `kubectl get secret cloudflared-credentials -n cloudflared`
2. Verify tunnel ID in configmap matches credentials file
3. Check logs: `kubectl logs -n cloudflared deployment/cloudflared`

## Architecture

```
Internet
  ↓
Cloudflare Edge (keycloak.maelkloud.com)
  ↓
Cloudflare Tunnel (mkloudlab)
  ↓
cloudflared pods in Kubernetes
  ↓
main-gateway-istio (Istio Gateway)
  ↓
Keycloak Service
```
