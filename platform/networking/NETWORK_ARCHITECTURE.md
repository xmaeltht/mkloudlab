# Network Architecture - Complete Overview

## Summary

The mkloudlab Kubernetes cluster uses **Tailscale VPN** for private access to all services:
- **Private Access**: Tailscale VPN for all applications (Keycloak, Monitoring stack)
- **No Public Access**: All services require Tailscale VPN connection

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                      PRIVATE VPN ACCESS (Tailscale)                  │
│                                                                       │
│   Your Devices → Tailscale VPN → mkloud-gateway → Istio Gateway     │
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

## Tailscale VPN Access

### Configuration
- **Operator Version**: 1.92.x
- **Namespace**: tailscale
- **Subnet Router**: mkloud-gateway
- **Advertised Routes**: 172.16.16.0/24 (MetalLB pool)
- **Tailscale IP**: 100.85.126.95

### Traffic Flow
```
Your Device (MacBook, Phone, etc.)
  ↓
Tailscale VPN (encrypted mesh network)
  ↓
mkloud-gateway subnet router (Tailscale operator in K8s)
  ↓
Route to 172.16.16.150 (main-gateway-istio LoadBalancer IP)
  ↓
Istio Gateway (HTTP/HTTPS)
  ↓
HTTPRoute (based on Host header)
  ↓
Backend Service (Keycloak, Grafana, Prometheus, etc.)
```

### Key Design Decisions

1. **Subnet Router with hostNetwork**:
   - Patch applied: `hostNetwork: true`
   - Required to access MetalLB IPs (only available on host network)
   - Alternative would be individual Tailscale ingress per service (more complex)

2. **Single Gateway Entry Point**:
   - All services accessible via 172.16.16.150 (main-gateway-istio)
   - Routing based on HTTP Host header
   - Simplified network policy management

3. **No sectionName Restrictions**:
   - HTTPRoutes accept both HTTP and HTTPS traffic
   - Allows flexible access patterns
   - HTTPS available with valid certificates

### All Services (via Tailscale)
- ✅ **Keycloak** (keycloak.maelkloud.com) - SSO & Identity
- ✅ **Grafana** (grafana.maelkloud.com) - Monitoring dashboards
- ✅ **Prometheus** (prometheus.maelkloud.com) - Metrics
- ✅ **Loki** (loki.maelkloud.com) - Logs
- ✅ **Tempo** (tempo.maelkloud.com) - Traces
- ✅ **Alloy** (alloy.maelkloud.com) - Telemetry collector

### Files
- `platform/networking/tailscale/helmrelease.yaml` - Operator deployment
- `platform/networking/tailscale/ingress-service.yaml` - Subnet router config
- `platform/networking/tailscale/namespace.yaml` - Namespace
- `platform/networking/tailscale/source.yaml` - Helm repository
- `platform/networking/tailscale/README.md` - Quick start guide
- `platform/networking/tailscale/SETUP.md` - Detailed setup guide

## Istio Gateway Configuration

### Main Gateway (main-gateway-istio)
- **Type**: LoadBalancer (MetalLB)
- **IP**: 172.16.16.150
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Namespace**: istio-system

### HTTPRoutes
Each service has its own HTTPRoute:
- Routes traffic based on `hostname` field
- No `sectionName` constraint (accepts HTTP and HTTPS)
- Direct to ClusterIP backend services

### HTTP vs HTTPS
- **HTTP (port 80)**: Always available
- **HTTPS (port 443)**: Available with valid certificates
- **Tailscale**: VPN encryption for all traffic
- **Certificates**: cert-manager with Let's Encrypt

## DNS Configuration

### Local DNS (/etc/hosts)
Services accessible via local DNS resolution:
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
- **Tailscale**: Sidecar injection disabled (requires direct network access)

### Key Policies
- `platform/identity/keycloak/network-policy.yaml` - Keycloak isolation
- `platform/kyverno/policies/istio-label-policy.yaml` - Istio injection rules (excludes tailscale ns)

## Security Considerations

### Tailscale VPN
- ✅ Zero-trust network (device authentication)
- ✅ WireGuard encryption
- ✅ ACLs in Tailscale admin (can restrict access per user/device)
- ✅ MFA support (Tailscale account level)
- ✅ Audit logs (Tailscale)

### Internal
- ✅ Network policies (Cilium + Kyverno)
- ✅ Istio mTLS (service-to-service)
- ✅ RBAC (Kubernetes)
- ✅ TLS certificates (cert-manager + Let's Encrypt)

## Accessing Services

### From Tailscale VPN
```bash
# Connect to Tailscale first
tailscale up

# Add to /etc/hosts
echo "172.16.16.150 keycloak.maelkloud.com grafana.maelkloud.com prometheus.maelkloud.com loki.maelkloud.com tempo.maelkloud.com alloy.maelkloud.com" | sudo tee -a /etc/hosts

# Access via browser
# HTTP:  http://grafana.maelkloud.com
# HTTPS: https://grafana.maelkloud.com
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

**Check Tailscale connection:**
```bash
tailscale status | grep mkloud-gateway
```

**Check subnet router:**
```bash
kubectl get pods -n tailscale
kubectl logs -n tailscale -l app=connector
```

**Verify routes approved:**
Visit Tailscale admin → Machines → mkloud-gateway → Routes

**Check hostNetwork enabled:**
```bash
kubectl get statefulset -n tailscale -o jsonpath='{.items[0].spec.template.spec.hostNetwork}'
# Should output: true
```

### 404 from Gateway

**Check HTTPRoute configuration:**
```bash
kubectl get httproute grafana-route -n observability -o yaml | grep sectionName
# Should have NO output (sectionName should be removed)
```

**Verify route is attached to gateway:**
```bash
kubectl describe httproute grafana-route -n observability
```

### Gateway IP not accessible

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
- **Tailscale**: Free tier (100 devices, 1 subnet router)
- **Infrastructure**: Self-hosted (Vagrant VMs)
- **Certificates**: Free (Let's Encrypt)

### At Scale
- **Tailscale**: May need paid plan for multiple subnet routers or more devices
- **Infrastructure**: Consider cloud Kubernetes if VMs become limiting

## References

- Tailscale Operator: https://tailscale.com/kb/1236/kubernetes-operator
- Tailscale Subnet Router: https://tailscale.com/kb/1019/subnets
- Istio Gateway API: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/
- Cilium Network Policies: https://docs.cilium.io/en/stable/security/policy/
