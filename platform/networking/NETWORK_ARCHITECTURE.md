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

## Public Access (Cloudflare Tunnel)

### Configuration
- **Tunnel Name**: mkloudlab-new
- **Tunnel ID**: 7ed713da-4da4-4354-9ba7-bb0a112873cb
- **Method**: Token-based (dashboard configured)
- **Namespace**: cloudflared
- **Deployment**: 2 replicas for HA

### Traffic Flow
```
Internet (HTTPS)
  ↓
Cloudflare Edge (TLS termination, DDoS protection, CDN)
  ↓
Cloudflare Tunnel (encrypted WireGuard)
  ↓
cloudflared pods (Kubernetes)
  ↓
Istio Gateway main-gateway-istio:80 (HTTP - internal)
  ↓
HTTPRoute (based on hostname)
  ↓
Backend Service (Keycloak)
```

### Key Design Decisions

1. **HTTP Backend**: cloudflared connects to Istio gateway via HTTP (not HTTPS)
   - Cloudflare handles TLS termination
   - Simpler configuration (no cert management for tunnel)
   - Still encrypted end-to-end (Cloudflare → cloudflared uses WireGuard)

2. **No HTTP→HTTPS Redirect**: Removed from Istio config
   - Would cause redirect loop (client already on HTTPS via Cloudflare)
   - Gateway accepts HTTP traffic from tunnel

3. **HTTPRoute Configuration**: Routes accept both HTTP and HTTPS
   - No `sectionName` constraint
   - Matches traffic on both ports

### Public Apps
- ✅ **keycloak.maelkloud.com** - Identity & SSO

### Files
- `platform/networking/cloudflared/deployment.yaml` - cloudflared deployment
- `platform/networking/cloudflared/namespace.yaml` - Namespace
- `platform/networking/cloudflared/README.md` - Documentation
- `platform/networking/cloudflared/SETUP.md` - Detailed setup guide

## Private Access (Tailscale VPN)

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
Istio Gateway (HTTP)
  ↓
HTTPRoute (based on Host header)
  ↓
Backend Service (Grafana, Prometheus, etc.)
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

3. **No MagicDNS Complexity**:
   - Services accessed via IP + Host header
   - Example: `curl -H "Host: grafana.maelkloud.com" http://172.16.16.150`
   - Could add Tailscale MagicDNS in future if needed

### Private Apps
- ✅ **Grafana** (grafana.maelkloud.com) - Monitoring dashboards
- ⚠️ **Prometheus** (prometheus.maelkloud.com) - Metrics (pod crashing - needs fix)
- ✅ **Loki** (loki.maelkloud.com) - Logs
- ✅ **Tempo** (tempo.maelkloud.com) - Traces
- ✅ **Alloy** (alloy.maelkloud.com) - Telemetry collector

### Files
- `platform/networking/tailscale/helmrelease.yaml` - Operator deployment
- `platform/networking/tailscale/ingress-service.yaml` - Subnet router config
- `platform/networking/tailscale/namespace.yaml` - Namespace
- `platform/networking/tailscale/source.yaml` - Helm repository

## Istio Gateway Configuration

### Main Gateway (main-gateway-istio)
- **Type**: LoadBalancer (MetalLB)
- **IP**: 172.16.16.150
- **Ports**: 80 (HTTP), 443 (HTTPS - currently unused)
- **Namespace**: istio-system

### HTTPRoutes
Each service has its own HTTPRoute:
- Routes traffic based on `hostname` field
- No `sectionName` constraint (accepts HTTP and HTTPS)
- Direct to ClusterIP backend services

### HTTP vs HTTPS
- **Current**: All traffic uses HTTP (port 80)
- **Cloudflare**: Handles HTTPS for public apps
- **Tailscale**: VPN encryption for private apps
- **Future**: Could enable HTTPS with cert-manager if needed

## DNS Configuration

### Public DNS (Cloudflare)
- **Domain**: maelkloud.com
- **Zone ID**: a1c69d5eb3fd80d8b015183e3eb07c8d
- **Record**: keycloak.maelkloud.com → CNAME → {tunnel-id}.cfargotunnel.com
- **Managed by**: Cloudflare Tunnel (auto-created)

### Internal DNS
- **CoreDNS**: Kubernetes default
- **Service Discovery**: {service}.{namespace}.svc.cluster.local
- **External-DNS**: Monitors Gateway/Ingress resources (currently disabled for tunnel hostnames)

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

### Public Apps (Cloudflare Tunnel)
- ✅ DDoS protection (Cloudflare)
- ✅ WAF capabilities (Cloudflare)
- ✅ TLS 1.3 encryption
- ✅ No exposed ports on home network
- ✅ Automatic cert rotation (Cloudflare managed)

### Private Apps (Tailscale)
- ✅ Zero-trust network (device authentication)
- ✅ WireGuard encryption
- ✅ ACLs in Tailscale admin (can restrict access per user/device)
- ✅ MFA support (Tailscale account level)
- ✅ Audit logs (Tailscale)

### Internal
- ✅ Network policies (Cilium + Kyverno)
- ✅ Istio mTLS (service-to-service)
- ✅ RBAC (Kubernetes)
- ⚠️ Gateway doesn't use HTTPS internally (acceptable - trust internal network)

## Accessing Services

### From Internet (Public Apps)
```bash
# Keycloak
https://keycloak.maelkloud.com
```

### From Tailscale VPN (Private Apps)
```bash
# Connect to Tailscale first
tailscale up

# Access via gateway IP with Host header
curl -H "Host: grafana.maelkloud.com" http://172.16.16.150

# Or use browser (configure /etc/hosts or use extension to set Host header)
# Future: Could use Tailscale MagicDNS for easier access
```

### From Within Cluster
```bash
# Direct service access
curl http://grafana.observability.svc.cluster.local

# Via gateway (same as external)
curl -H "Host: grafana.maelkloud.com" http://main-gateway-istio.istio-system.svc.cluster.local
```

## Troubleshooting

### Cloudflare Tunnel Issues

**530 Error**:
- Check cloudflared logs: `kubectl logs -n cloudflared deployment/cloudflared`
- Verify tunnel is connected and has correct config
- Check backend service is responding

**404 Error**:
- Verify HTTPRoute doesn't have `sectionName` constraint
- Check route is attached to gateway
- Verify hostname matches

**502 Bad Gateway**:
- Backend service is down
- Check: `kubectl get pods -n keycloak`
- Test direct access: `curl http://10.98.195.252:80`

### Tailscale Issues

**Can't reach 172.16.16.150**:
- Check subnet router: `kubectl get pods -n tailscale`
- Verify routes approved in Tailscale admin
- Check hostNetwork patch applied: `kubectl get sts -n tailscale -o jsonpath='{.items[0].spec.template.spec.hostNetwork}'`

**404 from Gateway**:
- Same as Cloudflare - check HTTPRoute configuration
- Verify Host header is set correctly

### General Network Issues

**Pods can't communicate**:
- Check Cilium: `kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium`
- Check network policies: `kubectl get networkpolicy -A`
- Test connectivity: `kubectl run test --image=nicolaka/netshoot -it --rm`

## Future Enhancements

### Potential Improvements
1. **MagicDNS Integration**: Easier access to private services (grafana.tailnet-name.ts.net)
2. **HTTPS on Gateway**: Add cert-manager for internal HTTPS
3. **More Public Apps**: Portfolio, blog, APIs via same tunnel
4. **Tailscale SSH**: Direct SSH to nodes via Tailscale
5. **Per-service Tailscale Ingress**: Individual Tailscale hostnames for each service
6. **External-DNS Integration**: Auto-create DNS records for new services

### Monitoring Improvements
1. **Fix Prometheus**: Investigate CrashLoopBackOff
2. **Path-based Routing**: Fix Loki/Tempo routes (might need specific paths)
3. **Auth Layer**: Add OAuth proxy for monitoring tools
4. **Dashboards**: Pre-configure Grafana dashboards for cluster metrics

## Cost Analysis

### Current Setup
- **Cloudflare**: Free tier (unlimited bandwidth for tunnel)
- **Tailscale**: Free tier (100 devices, 1 subnet router)
- **Infrastructure**: Self-hosted (Vagrant VMs)

### At Scale
- **Cloudflare**: Scales for free (tunnel + CDN)
- **Tailscale**: May need paid plan for multiple subnet routers or more devices
- **Infrastructure**: Consider cloud Kubernetes if VMs become limiting

## References

- Cloudflare Tunnel Docs: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
- Tailscale Subnet Router: https://tailscale.com/kb/1019/subnets
- Istio Gateway API: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/
- Cilium Network Policies: https://docs.cilium.io/en/stable/security/policy/
