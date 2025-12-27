# Domain-Based Service Access Setup

This guide explains how services are exposed via domain names (e.g., `keycloak.maelkloud.com`, `sonarqube.maelkloud.com`) using Istio Gateway API, MetalLB, and External-DNS.

## Quick Start

### Verify Setup

Run the verification script to check all components:

```bash
./scripts/verify-domain-access.sh
```

### Apply Configuration

If using Flux (recommended), changes will be automatically applied. Otherwise, apply manually:

```bash
# Apply Kyverno policy
kubectl apply -f platform/kyverno/policies/gateway-service-clusterip-policy.yaml

# Apply main gateway and HTTPRoutes
kubectl apply -f platform/istio/

# Apply alloy certificate
kubectl apply -f platform/observability/alloy/certificate.yaml
```

### Check Status

```bash
# Get LoadBalancer IP
kubectl get svc main-gateway-istio -n istio-system

# Check gateway status
kubectl get gateway main-gateway -n istio-system

# Check HTTPRoutes
kubectl get httproute -A

# Check external-dns logs
kubectl logs -n networking -l app.kubernetes.io/name=external-dns --tail=50
```

### Test Access

Once DNS records are created (may take a few minutes):

```bash
# Test HTTPS access
curl -I https://keycloak.maelkloud.com
curl -I https://sonarqube.maelkloud.com
curl -I https://grafana.maelkloud.com
curl -I https://alloy.maelkloud.com
```

## Overview

All services are accessible via their respective subdomains under `maelkloud.com`:
- **Keycloak**: `keycloak.maelkloud.com`
- **SonarQube**: `sonarqube.maelkloud.com`
- **Grafana**: `grafana.maelkloud.com`
- **Prometheus**: `prometheus.maelkloud.com`
- **Loki**: `loki.maelkloud.com`
- **Tempo**: `tempo.maelkloud.com`
- **Alloy**: `alloy.maelkloud.com`

## Architecture

### Components

1. **Main Gateway** (`platform/istio/main-gateway.yaml`)
   - Single LoadBalancer Gateway in `istio-system` namespace
   - Handles all incoming traffic for `*.maelkloud.com`
   - Uses MetalLB to provide external IP
   - TLS termination with service-specific certificates

2. **HTTPRoute Resources** (`platform/istio/httproutes.yaml`)
   - Routes traffic from main gateway to individual services
   - Each service has its own HTTPRoute pointing to the main gateway

3. **MetalLB** (`platform/networking/metallb/`)
   - Provides LoadBalancer IP for the main gateway
   - IP Pool: `172.16.16.150-172.16.16.250`

4. **External-DNS** (`platform/networking/external-dns/`)
   - Automatically creates DNS records in Cloudflare
   - Watches Gateway resources and LoadBalancer services
   - Creates wildcard A record: `*.maelkloud.com` → LoadBalancer IP

5. **Cert-Manager**
   - Issues and manages TLS certificates for each service
   - Uses Cloudflare DNS-01 challenge
   - Certificates stored as Secrets in respective namespaces

6. **Kyverno Policy** (`platform/kyverno/policies/gateway-service-clusterip-policy.yaml`)
   - Allows main-gateway service to use LoadBalancer
   - Converts all other Gateway API services to ClusterIP

## Configuration Details

### Main Gateway

The main gateway is configured with:
- **LoadBalancer service type** (allowed by Kyverno policy exception)
- **Wildcard hostname**: `*.maelkloud.com`
- **Individual HTTPS listeners** for each service with their specific certificates
- **External-DNS annotation**: `external-dns.alpha.kubernetes.io/hostname: "*.maelkloud.com"`

### HTTPRoute Resources

Each service has an HTTPRoute that:
- References the main gateway as parent
- Specifies the service hostname
- Routes to the backend service on the appropriate port

Example HTTPRoute structure:
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: keycloak-route
  namespace: keycloak
spec:
  parentRefs:
    - name: main-gateway
      namespace: istio-system
  hostnames:
    - keycloak.maelkloud.com
  rules:
    - backendRefs:
        - name: keycloak-keycloak-keycloakx-http
          port: 80
```

### Certificates

Each service has its own certificate managed by cert-manager:
- Certificates are created in the service's namespace
- ReferenceGrants allow the main gateway (in `istio-system`) to reference secrets in other namespaces
- Certificates are automatically renewed by cert-manager

### Kyverno Policy Exception

The Kyverno policy `gateway-service-clusterip`:
- Converts all Gateway API LoadBalancer services to ClusterIP
- **Exception**: Allows `main-gateway-istio` service in `istio-system` namespace to remain as LoadBalancer
- This ensures only the main gateway has external access

## DNS Configuration

External-DNS automatically:
1. Detects the LoadBalancer service created by the main gateway
2. Reads the `external-dns.alpha.kubernetes.io/hostname` annotation
3. Creates a wildcard A record in Cloudflare: `*.maelkloud.com` → LoadBalancer IP
4. Updates the record if the LoadBalancer IP changes

### Manual DNS Setup (if needed)

If external-dns is not working, you can manually create DNS records in Cloudflare:
1. Get the LoadBalancer IP:
   ```bash
   kubectl get svc main-gateway-istio -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```
2. Create A record in Cloudflare:
   - Type: A
   - Name: `*` (wildcard)
   - Content: `<LoadBalancer IP>`
   - Proxy: Disabled (for direct access) or Enabled (for Cloudflare proxy)

## Verification

### Check Gateway Status

```bash
# Check main gateway is programmed
kubectl get gateway main-gateway -n istio-system

# Check all HTTPRoutes
kubectl get httproute -A
```

### Check LoadBalancer Service

```bash
# Verify main gateway service has LoadBalancer IP
kubectl get svc main-gateway-istio -n istio-system

# Check other gateway services are ClusterIP
kubectl get svc -A -l gateway.istio.io/managed=istio.io-gateway-controller
```

### Check Certificates

```bash
# List all certificates
kubectl get certificate -A

# Check certificate status
kubectl describe certificate <cert-name> -n <namespace>
```

### Check DNS Records

```bash
# Query DNS for a service
dig keycloak.maelkloud.com
nslookup keycloak.maelkloud.com

# Check external-dns logs
kubectl logs -n networking -l app.kubernetes.io/name=external-dns
```

### Test Service Access

```bash
# Test HTTPS access (should return 200 or service-specific response)
curl -I https://keycloak.maelkloud.com
curl -I https://sonarqube.maelkloud.com
curl -I https://grafana.maelkloud.com
curl -I https://alloy.maelkloud.com
```

## Troubleshooting

### Services Not Accessible

1. **Check Gateway Status**:
   ```bash
   kubectl describe gateway main-gateway -n istio-system
   ```
   Look for `PROGRAMMED: True` in status.

2. **Check HTTPRoute Status**:
   ```bash
   kubectl describe httproute <route-name> -n <namespace>
   ```
   Verify the route is attached to the gateway.

3. **Check LoadBalancer IP**:
   ```bash
   kubectl get svc main-gateway-istio -n istio-system
   ```
   Ensure the service has an external IP assigned by MetalLB.

4. **Check DNS Records**:
   ```bash
   dig *.maelkloud.com
   ```
   Verify the wildcard DNS record points to the LoadBalancer IP.

### Certificate Issues

1. **Check Certificate Status**:
   ```bash
   kubectl describe certificate <cert-name> -n <namespace>
   ```
   Look for `Ready: True` in status.

2. **Check Certificate Secret**:
   ```bash
   kubectl get secret <cert-name> -n <namespace>
   ```
   Verify the secret exists and contains `tls.crt` and `tls.key`.

3. **Check ReferenceGrant**:
   ```bash
   kubectl get referencegrant -n <namespace>
   ```
   Ensure ReferenceGrant exists to allow gateway to reference secrets.

### External-DNS Not Creating Records

1. **Check External-DNS Logs**:
   ```bash
   kubectl logs -n networking -l app.kubernetes.io/name=external-dns
   ```

2. **Verify Cloudflare API Token**:
   ```bash
   kubectl get secret cloudflare-api-token-secret -n networking
   ```

3. **Check Gateway Annotation**:
   ```bash
   kubectl get gateway main-gateway -n istio-system -o yaml | grep external-dns
   ```

### MetalLB Not Assigning IP

1. **Check MetalLB Status**:
   ```bash
   kubectl get pods -n networking -l app.kubernetes.io/name=metallb
   ```

2. **Check IP Address Pool**:
   ```bash
   kubectl get ipaddresspool -n networking
   ```

3. **Check L2Advertisement**:
   ```bash
   kubectl get l2advertisement -n networking
   ```

## Security Considerations

1. **TLS Termination**: All traffic is terminated at the gateway with valid certificates
2. **Network Policies**: Consider adding network policies to restrict access if needed
3. **Cloudflare Proxy**: You can enable Cloudflare proxy for DDoS protection, but ensure SSL/TLS mode is set to "Full" or "Full (strict)"
4. **Certificate Management**: Certificates are automatically renewed by cert-manager

## Adding New Services

To add a new service:

1. **Create Certificate**:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: <service>-cert
     namespace: <namespace>
   spec:
     secretName: <service>-cert
     dnsNames:
       - <service>.maelkloud.com
     issuerRef:
       name: letsencrypt-dns-cloudflare
       kind: ClusterIssuer
   ```

2. **Add Listener to Main Gateway**:
   Add a new HTTPS listener in `platform/istio/main-gateway.yaml`:
   ```yaml
   - name: https-<service>
     port: 443
     protocol: HTTPS
     hostname: "<service>.maelkloud.com"
     tls:
       mode: Terminate
       certificateRefs:
         - name: <service>-cert
           kind: Secret
           namespace: <namespace>
   ```

3. **Create HTTPRoute**:
   Add to `platform/istio/httproutes.yaml`:
   ```yaml
   ---
   apiVersion: gateway.networking.k8s.io/v1beta1
   kind: HTTPRoute
   metadata:
     name: <service>-route
     namespace: <namespace>
   spec:
     parentRefs:
       - name: main-gateway
         namespace: istio-system
     hostnames:
       - <service>.maelkloud.com
     rules:
       - backendRefs:
           - name: <service-name>
             port: <port>
   ```

4. **Verify ReferenceGrant**:
   Ensure a ReferenceGrant exists in the service namespace to allow the gateway to reference secrets.

## References

- [Istio Gateway API Documentation](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
- [Gateway API Specification](https://gateway-api.sigs.k8s.io/)
- [External-DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Cert-Manager Cloudflare DNS-01](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)

