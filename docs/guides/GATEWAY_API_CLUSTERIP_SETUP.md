# Gateway API with ClusterIP Configuration

This guide explains how the cluster is configured to use Istio Gateway API without LoadBalancer services, leveraging ClusterIP services instead.

## Overview

All applications in this cluster use Istio Gateway API for ingress traffic, with all gateway services configured to use `ClusterIP` instead of `LoadBalancer`. This eliminates the need for external LoadBalancer services while still providing full Gateway API functionality.

## Implementation Status

✅ **Fully Implemented and Active**

- All Gateway API services converted to ClusterIP
- Kyverno policy active and preventing new LoadBalancer services
- All gateways are programmed and ready
- 0 LoadBalancer services remaining in the cluster

## Architecture

### Gateway Configuration

Each application has its own Gateway resource configured with:
- **Gateway API** (`gateway.networking.k8s.io/v1beta1`)
- **Istio GatewayClass** (`gatewayClassName: istio`)
- **HTTPS listeners** with TLS termination
- **Cert-manager certificates** using Cloudflare DNS-01 challenges

### Service Type Management

Two mechanisms ensure no LoadBalancer services are created:

1. **Kyverno Policy** (Primary): Automatically converts any LoadBalancer service created by Istio Gateway API to ClusterIP
   - Policy: `gateway-service-clusterip`
   - Location: `platform/kyverno/policies/gateway-service-clusterip-policy.yaml`
   - Status: ✅ Active and ready
   - Matches services with label: `gateway.istio.io/managed=istio.io-gateway-controller`

2. **Gateway Annotations**: All Gateway resources include the annotation:
   ```yaml
   annotations:
     networking.istio.io/service-type: "ClusterIP"
   ```
   Note: While this annotation is set, the Kyverno policy provides the actual enforcement.

## Applications Using Gateway API

The following applications are configured with Gateway API:

- **Keycloak**: `keycloak.maelkloud.com`
- **SonarQube**: `sonarqube.maelkloud.com`
- **Grafana**: `grafana.maelkloud.com`
- **Prometheus**: `prometheus.maelkloud.com`
- **Loki**: `loki.maelkloud.com`
- **Tempo**: `tempo.maelkloud.com`

## Main Gateway (Optional)

A shared main gateway configuration is available in `platform/istio/main-gateway.yaml`:
- Namespace: `istio-system`
- Hostname: `*.maelkloud.com`
- Includes all application certificates (keycloak, sonarqube, grafana, prometheus, loki, tempo)

**Note**: This is optional. Each application currently uses its own Gateway resource, which is the recommended approach for better isolation and management.

## Certificates

All certificates are managed by cert-manager:
- **Issuer**: `letsencrypt-dns-cloudflare` (ClusterIssuer)
- **Challenge**: DNS-01 using Cloudflare API token
- **Domain**: `maelkloud.com` and subdomains

Certificates are automatically issued and renewed by cert-manager using the Cloudflare API token secret stored in the `cert-manager` namespace.

## Migration Script

A migration script is available to patch existing LoadBalancer services:

```bash
./scripts/patch-gateway-services-clusterip.sh
```

This script will:
1. Find all LoadBalancer services created by Istio Gateway API
2. Patch them to use ClusterIP
3. Remove any external IPs
4. Verify the patch was successful

**Status**: ✅ All services have been migrated (completed during initial implementation)

## External Access

Since all services use ClusterIP, external access is provided through:

1. **Cloudflare Tunnel** (recommended): Configure a Cloudflare tunnel to route traffic to the Istio ingress gateway
2. **NodePort**: Configure the Istio ingress gateway service to use NodePort
3. **External Load Balancer**: Use an external load balancer (e.g., MetalLB, cloud provider LB) that points to the ClusterIP services

## Verification

### Check Gateway API Services

Verify all Gateway API services are using ClusterIP:

```bash
# List all Gateway API services and their types
kubectl get svc -A -l gateway.istio.io/managed=istio.io-gateway-controller \
  -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type
```

Expected output (all should be ClusterIP):
```
NAMESPACE      NAME                        TYPE
keycloak       keycloak-gateway-istio     ClusterIP
observability  grafana-gateway-istio      ClusterIP
observability  loki-gateway-istio         ClusterIP
observability  prometheus-gateway-istio   ClusterIP
observability  tempo-gateway-istio        ClusterIP
sonarqube      sonarqube-gateway-istio    ClusterIP
```

### Check for Any LoadBalancer Services

Verify no LoadBalancer services exist for Gateway API:

```bash
# Check for LoadBalancer services created by Istio Gateway API
kubectl get svc -A -l gateway.istio.io/managed=istio.io-gateway-controller -o json | \
  jq -r '.items[] | select(.spec.type == "LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name)"'
```

This should return no results.

### Check Gateway Status

Verify all gateways are programmed and ready:

```bash
kubectl get gateway -A
```

All gateways should show `PROGRAMMED: True`.

### Check Kyverno Policy

Verify the Kyverno policy is active:

```bash
kubectl get clusterpolicy gateway-service-clusterip
kubectl get clusterpolicy gateway-service-clusterip -o jsonpath='{.status.ready}'
```

Should return `true`.

## Troubleshooting

### Services Still Using LoadBalancer

If services are still being created as LoadBalancer (should not happen with active policy):

1. **Check Kyverno Policy Status**:
   ```bash
   kubectl get clusterpolicy gateway-service-clusterip
   kubectl describe clusterpolicy gateway-service-clusterip
   ```

2. **Check Kyverno Logs**:
   ```bash
   kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno --tail=50
   ```

3. **Verify Policy Conditions**:
   ```bash
   kubectl get clusterpolicy gateway-service-clusterip -o yaml | grep -A 10 "preconditions"
   ```

4. **Manually Patch Services** (if needed):
   ```bash
   ./scripts/patch-gateway-services-clusterip.sh
   ```

5. **Check Service Labels**:
   ```bash
   kubectl get svc <service-name> -n <namespace> --show-labels
   ```
   Ensure the service has: `gateway.istio.io/managed=istio.io-gateway-controller`

### Gateway Not Accessible

If gateways are not accessible externally:

1. **Verify Gateway Status**:
   ```bash
   kubectl get gateway -A
   kubectl describe gateway <gateway-name> -n <namespace>
   ```

2. **Check HTTPRoute Status**:
   ```bash
   kubectl get httproute -A
   kubectl describe httproute <route-name> -n <namespace>
   ```

3. **Verify Certificates**:
   ```bash
   kubectl get certificate -A
   kubectl describe certificate <cert-name> -n <namespace>
   ```

4. **Check Certificate Secrets**:
   ```bash
   kubectl get secret <cert-name> -n <namespace>
   ```
   The secret should exist and contain `tls.crt` and `tls.key`.

### Kyverno Policy Not Working

If the Kyverno policy is not converting services:

1. **Check Policy Admission**:
   ```bash
   kubectl get clusterpolicy gateway-service-clusterip -o jsonpath='{.spec.admission}'
   ```
   Should be `true`.

2. **Test Policy with Dry Run**:
   ```bash
   kubectl run test-pod --image=nginx --dry-run=client -o yaml | \
     kubectl label --dry-run=client -f - gateway.istio.io/managed=istio.io-gateway-controller
   ```

3. **Check Kyverno Webhook**:
   ```bash
   kubectl get validatingwebhookconfigurations | grep kyverno
   kubectl get mutatingwebhookconfigurations | grep kyverno
   ```

## Current Configuration Summary

### Active Services (All ClusterIP)
- `keycloak/keycloak-gateway-istio` → ClusterIP ✅
- `sonarqube/sonarqube-gateway-istio` → ClusterIP ✅
- `observability/grafana-gateway-istio` → ClusterIP ✅
- `observability/prometheus-gateway-istio` → ClusterIP ✅
- `observability/loki-gateway-istio` → ClusterIP ✅
- `observability/tempo-gateway-istio` → ClusterIP ✅

### Active Policies
- `gateway-service-clusterip` → Active ✅

### LoadBalancer Services
- **Count**: 0 ✅

## References

- [Istio Gateway API Documentation](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
- [Gateway API Specification](https://gateway-api.sigs.k8s.io/)
- [Kyverno Policies](https://kyverno.io/docs/writing-policies/)
- [Cert-Manager Cloudflare DNS-01](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)

