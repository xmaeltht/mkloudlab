# Cloudflare Tunnel Setup - WORKING CONFIGURATION

## Summary

Keycloak is now publicly accessible via Cloudflare Tunnel at **https://keycloak.maelkloud.com**

## Architecture

```
Internet (HTTPS)
  ↓
Cloudflare Edge (HTTPS termination)
  ↓
Cloudflare Tunnel (encrypted)
  ↓
cloudflared pods (Kubernetes)
  ↓
main-gateway-istio (HTTP - port 80)
  ↓
Keycloak Service
```

## Key Configuration Details

- **Tunnel Name**: mkloudlab-new
- **Tunnel ID**: 7ed713da-4da4-4354-9ba7-bb0a112873cb
- **Method**: Token-based (configured via Cloudflare dashboard)
- **Backend**: HTTP (Cloudflare handles HTTPS)
- **Public App**: keycloak.maelkloud.com
- **Private Apps**: Monitoring tools (via Tailscale - to be configured)

## Important Notes

1. **HTTP vs HTTPS**: Cloudflared connects to the Istio gateway via HTTP (port 80), NOT HTTPS. Cloudflare handles TLS termination.

2. **No HTTP Redirect**: The HTTP→HTTPS redirect was removed from Istio because Cloudflare handles HTTPS. Traffic flow:
   - Client → HTTPS (Cloudflare)
   - Cloudflare → cloudflared → HTTP (Istio gateway)
   - Response follows same path back

3. **HTTPRoute Configuration**: The keycloak HTTPRoute was updated to accept both HTTP and HTTPS traffic (removed `sectionName` constraint).

4. **DNS**: CNAME record `keycloak.maelkloud.com` points to tunnel hostname (auto-created by Cloudflare).

## Files Created

- `namespace.yaml` - Cloudflared namespace
- `deployment.yaml` - Cloudflared deployment with tunnel token
- `README.md` - General documentation
- `SETUP.md` - This file

## Secret (Not in Git)

The tunnel token is stored in Kubernetes secret `cloudflared-token`:
```bash
kubectl get secret cloudflared-token -n cloudflared
```

To recreate from Cloudflare dashboard if needed.

## Testing

Test public access:
```bash
curl -I https://keycloak.maelkloud.com
# Should return HTTP 302 redirect to /admin/

curl -L https://keycloak.maelkloud.com/admin/
# Should load Keycloak Administration UI
```

## Troubleshooting

### 404 Error
- Check HTTPRoute doesn't have `sectionName` constraint
- Verify route is attached to gateway

### 301 Redirect Loop
- Remove HTTP→HTTPS redirect from Istio
- Ensure cloudflared connects to HTTP not HTTPS

### 502 Bad Gateway
- Check gateway service is accessible: `curl http://10.98.195.252:80`
- Verify Keycloak pods are running
- Check cloudflared logs: `kubectl logs -n cloudflared deployment/cloudflared`

## Next Steps

- Configure Tailscale ingress for monitoring tools (Grafana, Prometheus, etc.)
- Clean up unnecessary Tailscale installations on Vagrant VMs
- Consider adding more public apps via same tunnel
