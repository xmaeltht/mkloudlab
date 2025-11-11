# Istio VirtualService Templates

This directory contains templates and examples for creating Istio VirtualService configurations for applications.

## VirtualService vs HTTPRoute

We use **Istio VirtualService** instead of Gateway API HTTPRoute because:

1. **Better Istio Integration**: VirtualService is native to Istio and provides more features
2. **Advanced Traffic Management**: Load balancing, circuit breaking, retries, timeouts
3. **Security Features**: mTLS, authorization policies
4. **Observability**: Better integration with Istio telemetry
5. **Performance**: More efficient routing within Istio service mesh

## Template Usage

### Basic Template

Use `virtualservice-template.yaml` as a starting point for new applications:

```bash
# Copy the template
cp istio/templates/virtualservice-template.yaml myapp-vs.yaml

# Replace placeholders:
# {{APP_NAME}} → your-app-name
# {{NAMESPACE}} → your-namespace
# {{DOMAIN}} → your.domain.com
# {{SERVICE_NAME}} → your-service-name
# {{SERVICE_PORT}} → service-port
# {{TARGET_PORT}} → container-port
```

### Example: Keycloak VirtualService

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: keycloak-vs
  namespace: keycloak
spec:
  hosts:
    - keycloak.maelkloud.com
  gateways:
    - keycloak/keycloak-gateway
  http:
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: keycloak
            port:
              number: 8080
```

## Certificate Management

All applications use **Cloudflare DNS-01** challenges for certificate management:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-cert
  namespace: app-namespace
spec:
  secretName: app-cert
  issuerRef:
    name: letsencrypt-dns-cloudflare # DNS-01 challenge
    kind: ClusterIssuer
  dnsNames:
    - app.maelkloud.com
```

## Gateway Configuration

Each application gets its own Gateway for TLS termination:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: app-gateway
  namespace: app-namespace
spec:
  gatewayClassName: istio
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: app.maelkloud.com
      tls:
        mode: Terminate
        certificateRefs:
          - name: app-cert
            kind: Secret
```

## Advanced Features

### Load Balancing

```yaml
http:
  - route:
      - destination:
          host: my-service
          port:
            number: 8080
        weight: 80
      - destination:
          host: my-service-v2
          port:
            number: 8080
        weight: 20
```

### Circuit Breaker

```yaml
http:
  - route:
      - destination:
          host: my-service
          port:
            number: 8080
    fault:
      delay:
        percentage:
          value: 0.1
        fixedDelay: 5s
```

### Retry Policy

```yaml
http:
  - route:
      - destination:
          host: my-service
          port:
            number: 8080
    retries:
      attempts: 3
      perTryTimeout: 2s
```

## Migration from HTTPRoute

To migrate from HTTPRoute to VirtualService:

1. **Replace HTTPRoute** with VirtualService
2. **Update gateway reference** from `parentRefs` to `gateways`
3. **Change destination format** from `backendRefs` to `destination`
4. **Add Istio-specific features** as needed

### Before (HTTPRoute):

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
spec:
  parentRefs:
    - name: my-gateway
  rules:
    - backendRefs:
        - name: my-service
          port: 8080
```

### After (VirtualService):

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
    - my-namespace/my-gateway
  http:
    - route:
        - destination:
            host: my-service
            port:
              number: 8080
```
