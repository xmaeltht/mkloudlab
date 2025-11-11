# Deployment Order & Structure

## Prerequisites (Deploy BEFORE ArgoCD)

1. **Gateway API** - Install Gateway API CRDs
2. **local-path Storage** - Storage provisioner for PVCs
3. **metrics-server** - Resource metrics collection
4. **cert-manager** - TLS certificate management
5. **Istio** - Service mesh and ingress
6. **ArgoCD** - GitOps controller

## ArgoCD Applications (Deploy AFTER prerequisites)

1. **Infrastructure Layer**
   - external-secrets
   - kyverno-engine
   - kyverno-policies
   - security-config

2. **Application Layer**
   - keycloak
   - sonarqube
   - monitoring (Prometheus & Grafana)
   - alloy (Grafana Alloy OTLP collector)
   - tempo (Grafana Tempo traces)
   - loki-stack

## Gateway API Resources Needed

Each application needs:

- Gateway (shared or per-app)
- HTTPRoute
- Service
- Certificate (via cert-manager)
- VirtualService (Istio-specific)
