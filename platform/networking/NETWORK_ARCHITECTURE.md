# Network Architecture - Complete Overview

## Summary

The mkloudlab Kubernetes cluster uses **Cloudflare DNS + MetalLB + Istio Gateway API** for service access:
- **Domain-based Access**: All services accessible via `*.maelkloud.com` subdomains
- **TLS Everywhere**: cert-manager with Let's Encrypt via Cloudflare DNS-01
- **HTTP to HTTPS Redirect**: Automatic for all domains

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SERVICE ACCESS                                │
│                                                                       │
│   Your Device → DNS (*.maelkloud.com) → MetalLB → Istio Gateway     │
│                                                                       │
│   ✅ keycloak.maelkloud.com (SSO & Identity)                         │
│   ✅ grafana.maelkloud.com (Monitoring Dashboards)                   │
│   ✅ prometheus.maelkloud.com (Metrics)                              │
│   ✅ loki.maelkloud.com (Logs)                                       │
│   ✅ tempo.maelkloud.com (Traces)                                    │
│   ✅ alloy.maelkloud.com (Telemetry Collector)                       │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        CLUSTER INTERNALS                             │
│                                                                       │
│   Vagrant VMs (172.16.16.0/24)                                       │
│    ├─ kcontroller (172.16.16.100) - Master Node                     │
│    ├─ knode1-3 (172.16.16.101-103) - Worker Nodes                   │
│    └─ MetalLB Pool (172.16.16.150-250) - LoadBalancer IPs           │
│                                                                       │
│   CNI: Cilium (Pod CIDR: 192.168.0.0/16)                            │
│   Service Mesh: Istio (Gateway API)                                 │
└─────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

```
Your Device (Browser)
  ↓
DNS Resolution (Cloudflare → External-DNS)
  ↓
MetalLB LoadBalancer IP (172.16.16.150)
  ↓
Istio Gateway (HTTP/HTTPS with TLS termination)
  ↓
HTTPRoute (based on Host header)
  ↓
Backend Service (Keycloak, Grafana, Prometheus, etc.)
```

## Istio Gateway Configuration

### Main Gateway (main-gateway-istio)
- **Type**: LoadBalancer (MetalLB)
- **IP**: 172.16.16.150
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Namespace**: istio-system

### HTTPRoutes
Each service has its own HTTPRoute:
- Routes traffic based on `hostname` field
- Direct to ClusterIP backend services

### HTTP vs HTTPS
- **HTTP (port 80)**: Redirects to HTTPS
- **HTTPS (port 443)**: TLS-terminated at gateway with valid certificates
- **Certificates**: cert-manager with Let's Encrypt (Cloudflare DNS-01)

### All Services
- **Keycloak** (keycloak.maelkloud.com) - SSO & Identity
- **Grafana** (grafana.maelkloud.com) - Monitoring dashboards
- **Prometheus** (prometheus.maelkloud.com) - Metrics
- **Loki** (loki.maelkloud.com) - Logs
- **Tempo** (tempo.maelkloud.com) - Traces
- **Alloy** (alloy.maelkloud.com) - Telemetry collector

## DNS Configuration

### External DNS (Cloudflare)
- **Provider**: Cloudflare
- **Auto-creates**: DNS records for Gateway resources
- **Wildcard**: `*.maelkloud.com` → MetalLB LoadBalancer IP

### Local DNS (/etc/hosts)
For local access without external DNS:
```bash
172.16.16.150 keycloak.maelkloud.com grafana.maelkloud.com prometheus.maelkloud.com loki.maelkloud.com tempo.maelkloud.com alloy.maelkloud.com
```

### Internal DNS
- **CoreDNS**: Kubernetes default
- **Service Discovery**: {service}.{namespace}.svc.cluster.local

## MetalLB Configuration

### IP Address Pool
- **Name**: vagrant-pool
- **Range**: 172.16.16.150 - 172.16.16.250
- **Type**: Layer 2 (ARP)
- **Used by**: Istio Gateway (main-gateway-istio)

### Allocated IPs
- 172.16.16.150 - main-gateway-istio (shared entry point)

## Network Policies

### Philosophy
- **Zero-trust by default** where critical
- **Explicit allow rules** for required traffic
- **Keycloak**: Strict ingress/egress controls

### Key Policies
- `platform/identity/keycloak/network-policy.yaml` - Keycloak isolation
- `platform/kyverno/policies/istio-label-policy.yaml` - Istio injection rules

## Security

- Network policies (Cilium + Kyverno)
- Istio mTLS (service-to-service)
- RBAC (Kubernetes)
- TLS certificates (cert-manager + Let's Encrypt)

## Accessing Services

### From Local Network
```bash
# Add to /etc/hosts (if not using external DNS)
echo "172.16.16.150 keycloak.maelkloud.com grafana.maelkloud.com prometheus.maelkloud.com loki.maelkloud.com tempo.maelkloud.com alloy.maelkloud.com" | sudo tee -a /etc/hosts

# Access via browser
# https://grafana.maelkloud.com
# https://keycloak.maelkloud.com
```

### From Within Cluster
```bash
# Direct service access
curl http://grafana.observability.svc.cluster.local

# Via gateway (same as external)
curl -H "Host: grafana.maelkloud.com" http://main-gateway-istio.istio-system.svc.cluster.local
```

## Troubleshooting

### Can't reach services

**Verify MetalLB assigned the IP:**
```bash
kubectl get svc main-gateway-istio -n istio-system
# EXTERNAL-IP should be 172.16.16.150
```

**Test from within cluster:**
```bash
kubectl run test --image=nicolaka/netshoot -it --rm -- \
  curl -H "Host: grafana.maelkloud.com" http://172.16.16.150
```

### 404 from Gateway

**Check HTTPRoute configuration:**
```bash
kubectl get httproute grafana-route -n observability -o yaml
```

**Verify route is attached to gateway:**
```bash
kubectl describe httproute grafana-route -n observability
```

### General Network Issues

**Check Cilium:**
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium
```

**Check network policies:**
```bash
kubectl get networkpolicy -A
```

## Cost Analysis

### Current Setup
- **Infrastructure**: Self-hosted (Vagrant VMs)
- **Certificates**: Free (Let's Encrypt)
- **DNS**: Cloudflare (free tier)

## References

- Istio Gateway API: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/
- Cilium Network Policies: https://docs.cilium.io/en/stable/security/policy/
- MetalLB: https://metallb.universe.tf/
- cert-manager: https://cert-manager.io/docs/
