# Domain Access Setup - Implementation Summary

## What Was Implemented

This document summarizes the changes made to enable domain-based access to all services via `*.maelkloud.com` subdomains.

## Files Created/Modified

### New Files

1. **`platform/kyverno/policies/gateway-service-clusterip-policy.yaml`**
   - Kyverno policy that allows main-gateway to use LoadBalancer
   - Converts all other Gateway API services to ClusterIP

2. **`platform/istio/httproutes.yaml`**
   - HTTPRoute resources for all services pointing to main gateway
   - Services: keycloak, sonarqube, grafana, prometheus, loki, tempo, alloy

3. **`platform/observability/alloy/certificate.yaml`**
   - TLS certificate for alloy service

4. **`scripts/verify-domain-access.sh`**
   - Verification script to check all components

5. **`docs/guides/DOMAIN_ACCESS_SETUP.md`**
   - Comprehensive documentation

### Modified Files

1. **`platform/istio/main-gateway.yaml`**
   - Added alloy HTTPS listener
   - Already configured with LoadBalancer annotation

2. **`platform/observability/alloy/kustomization.yaml`**
   - Added certificate.yaml to resources

## Architecture

```
Internet
   ↓
Cloudflare DNS (*.maelkloud.com → LoadBalancer IP)
   ↓
MetalLB LoadBalancer (172.16.16.150-172.16.16.250)
   ↓
Main Gateway (istio-system/main-gateway)
   ↓
HTTPRoutes (route by hostname)
   ↓
Backend Services
```

## Services Configured

| Service | Domain | Namespace | Backend Service | Port |
|---------|--------|-----------|-----------------|------|
| Keycloak | keycloak.maelkloud.com | keycloak | keycloak-keycloak-keycloakx-http | 80 |
| SonarQube | sonarqube.maelkloud.com | sonarqube | sonarqube-sonarqube-sonarqube | 9000 |
| Grafana | grafana.maelkloud.com | observability | grafana | 80 |
| Prometheus | prometheus.maelkloud.com | observability | prometheus-server | 80 |
| Loki | loki.maelkloud.com | observability | loki | 3100 |
| Tempo | tempo.maelkloud.com | observability | tempo | 3200 |
| Alloy | alloy.maelkloud.com | observability | alloy-gateway | 12345 |

## Key Components

### 1. Main Gateway
- **Location**: `istio-system` namespace
- **Type**: LoadBalancer (allowed by Kyverno exception)
- **Function**: Single entry point for all `*.maelkloud.com` traffic
- **TLS**: Terminates TLS with service-specific certificates

### 2. HTTPRoutes
- **Location**: Service namespaces
- **Function**: Route traffic from main gateway to backend services
- **Parent**: main-gateway in istio-system

### 3. External-DNS
- **Function**: Automatically creates DNS records in Cloudflare
- **Configuration**: Watches Gateway resources and LoadBalancer services
- **DNS Record**: Wildcard A record `*.maelkloud.com` → LoadBalancer IP

### 4. MetalLB
- **Function**: Provides LoadBalancer IP for main gateway
- **IP Pool**: 172.16.16.150-172.16.16.250

### 5. Certificates
- **Issuer**: letsencrypt-dns-cloudflare (ClusterIssuer)
- **Challenge**: DNS-01 using Cloudflare API
- **Management**: cert-manager with automatic renewal

## Deployment Steps

1. **Apply Kyverno Policy**:
   ```bash
   kubectl apply -f platform/kyverno/policies/gateway-service-clusterip-policy.yaml
   ```

2. **Apply Main Gateway and HTTPRoutes**:
   ```bash
   kubectl apply -f platform/istio/
   ```

3. **Apply Alloy Certificate**:
   ```bash
   kubectl apply -f platform/observability/alloy/certificate.yaml
   ```

4. **Verify Setup**:
   ```bash
   ./scripts/verify-domain-access.sh
   ```

5. **Check LoadBalancer IP**:
   ```bash
   kubectl get svc main-gateway-istio -n istio-system
   ```

6. **Wait for DNS Propagation**:
   - External-DNS will create DNS records automatically
   - May take 2-5 minutes for DNS propagation

7. **Test Access**:
   ```bash
   curl -I https://keycloak.maelkloud.com
   ```

## Verification Checklist

- [ ] Main gateway is programmed (`kubectl get gateway main-gateway -n istio-system`)
- [ ] LoadBalancer service has external IP (`kubectl get svc main-gateway-istio -n istio-system`)
- [ ] All HTTPRoutes exist and reference main-gateway (`kubectl get httproute -A`)
- [ ] All certificates are ready (`kubectl get certificate -A`)
- [ ] External-DNS pod is running (`kubectl get pods -n networking -l app.kubernetes.io/name=external-dns`)
- [ ] DNS records created in Cloudflare (check Cloudflare dashboard or use `dig *.maelkloud.com`)
- [ ] HTTPS access works (`curl -I https://keycloak.maelkloud.com`)

## Troubleshooting

### LoadBalancer IP Not Assigned

1. Check MetalLB:
   ```bash
   kubectl get pods -n networking -l app.kubernetes.io/name=metallb
   kubectl get ipaddresspool -n networking
   ```

2. Check if IP pool has available IPs

### DNS Records Not Created

1. Check External-DNS logs:
   ```bash
   kubectl logs -n networking -l app.kubernetes.io/name=external-dns
   ```

2. Verify Cloudflare API token:
   ```bash
   kubectl get secret cloudflare-api-token-secret -n networking
   ```

3. Check Gateway annotation:
   ```bash
   kubectl get gateway main-gateway -n istio-system -o yaml | grep external-dns
   ```

### Services Not Accessible

1. Check HTTPRoute status:
   ```bash
   kubectl describe httproute <route-name> -n <namespace>
   ```

2. Check backend service:
   ```bash
   kubectl get svc <service-name> -n <namespace>
   ```

3. Check gateway logs:
   ```bash
   kubectl logs -n istio-system -l istio.io/gateway-name=main-gateway
   ```

## Notes

- Individual service gateways (keycloak-gateway, sonarqube-gateway, etc.) remain as ClusterIP and won't interfere
- The main gateway is the only LoadBalancer service (enforced by Kyverno policy)
- All TLS certificates are managed by cert-manager with automatic renewal
- DNS records are managed automatically by external-dns
- No tunnels or port-forwarding required - all traffic goes through the LoadBalancer

## References

- Full documentation: `docs/guides/DOMAIN_ACCESS_SETUP.md`
- Verification script: `scripts/verify-domain-access.sh`
- Main gateway: `platform/istio/main-gateway.yaml`
- HTTPRoutes: `platform/istio/httproutes.yaml`

