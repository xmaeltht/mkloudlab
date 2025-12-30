# Tailscale VPN Access

Private VPN access to monitoring tools (Grafana, Prometheus, Loki, Tempo, Alloy) using Tailscale subnet routing.

## Overview

The Tailscale operator deploys a subnet router that advertises the cluster's MetalLB IP pool (172.16.16.0/24) to your Tailscale network. This allows secure, private access to monitoring tools from any device connected to your Tailscale VPN.

## Architecture

```
Your Device → Tailscale VPN → mkloud-gateway → Istio Gateway (172.16.16.150) → Services
```

## Quick Start

### Prerequisites

1. Tailscale account
2. OAuth client created in Tailscale admin console
3. Tailscale installed on your access device

### Deploy

```bash
# 1. Create OAuth secret (DO NOT COMMIT!)
kubectl create secret generic tailscale-operator-oauth \
  -n tailscale \
  --from-literal=client-id='YOUR_CLIENT_ID' \
  --from-literal=client-secret='YOUR_CLIENT_SECRET'

# 2. Apply manifests
kubectl apply -f platform/networking/tailscale/

# 3. Apply hostNetwork patch (REQUIRED!)
STS_NAME=$(kubectl get statefulset -n tailscale -o jsonpath='{.items[0].metadata.name}')
kubectl patch statefulset $STS_NAME -n tailscale --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true},
       {"op": "add", "path": "/spec/template/spec/dnsPolicy", "value": "ClusterFirstWithHostNet"}]'

# 4. Approve subnet routes in Tailscale admin console
# Visit: https://login.tailscale.com/admin/machines
# Find: mkloud-gateway
# Approve: 172.16.16.0/24

# 5. Fix HTTPRoutes to accept HTTP traffic
for route in alloy-route grafana-route loki-route prometheus-route tempo-route; do
  kubectl patch httproute $route -n observability --type='json' \
    -p='[{"op": "remove", "path": "/spec/parentRefs/0/sectionName"}]'
done
```

### Access Services

```bash
# Connect to Tailscale
tailscale up

# Access Grafana (example)
curl -H "Host: grafana.maelkloud.com" http://172.16.16.150

# Or add to /etc/hosts for browser access:
# 172.16.16.150 grafana.maelkloud.com
```

## Files

- `namespace.yaml` - Tailscale namespace
- `source.yaml` - Helm repository for Tailscale operator
- `helmrelease.yaml` - Tailscale operator deployment with OAuth config
- `ingress-service.yaml` - Subnet router Connector resource
- `SETUP.md` - Detailed setup guide
- `README.md` - This file

## Key Features

- **Zero-trust access**: Device authentication required
- **Encrypted**: WireGuard encryption for all traffic
- **No exposed ports**: No public IP required
- **Multi-device**: Access from MacBook, phone, tablet, etc.
- **ACL support**: Restrict access per user/device in Tailscale admin

## Important Notes

1. **OAuth Secret**: Keep `tailscale-operator-oauth` secret secure and out of git
2. **hostNetwork**: Required for subnet router to access MetalLB IPs
3. **VM Installations**: Vagrant VMs do NOT need Tailscale installed - operator handles everything
4. **HTTPRoute Config**: Routes must accept HTTP (no `sectionName` constraint)

## Private Apps (via Tailscale)

- ✅ Grafana (grafana.maelkloud.com)
- ⚠️ Prometheus (prometheus.maelkloud.com) - pod crashing, needs fix
- ✅ Loki (loki.maelkloud.com)
- ✅ Tempo (tempo.maelkloud.com)
- ✅ Alloy (alloy.maelkloud.com)

## Troubleshooting

See `SETUP.md` for detailed troubleshooting steps.

Quick checks:
```bash
# Verify operator running
kubectl get pods -n tailscale

# Check subnet router logs
kubectl logs -n tailscale -l app=connector

# Verify hostNetwork enabled
kubectl get statefulset -n tailscale -o jsonpath='{.items[0].spec.template.spec.hostNetwork}'

# Test connectivity
curl -H "Host: grafana.maelkloud.com" http://172.16.16.150
```

## Documentation

- Full setup guide: `SETUP.md`
- Network architecture: `../NETWORK_ARCHITECTURE.md`

## References

- Tailscale Operator: https://tailscale.com/kb/1236/kubernetes-operator
- Subnet Router: https://tailscale.com/kb/1019/subnets
- OAuth Clients: https://tailscale.com/kb/1215/oauth-clients
