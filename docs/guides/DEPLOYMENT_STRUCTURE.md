# Deployment Order & Structure

## Prerequisites (Deploy BEFORE Flux)

1. **Gateway API** - Install Gateway API CRDs
2. **local-path Storage** - Storage provisioner for PVCs
3. **metrics-server** - Resource metrics collection
4. **cert-manager** - TLS certificate management
5. **Istio** - Installed via Flux HelmRelease (see platform/flux/apps/istio.yaml)

## Flux Applications (Deploy AFTER prerequisites)

Apply Flux app definitions with `task install:apps`. Flux then reconciles from Git and deploys the following.

### 1. Infrastructure Layer

- external-secrets (`platform/external-secrets`)
- kyverno (`platform/kyverno` via HelmRelease)
- kyverno-policies (`platform/kyverno`)
- security-config (`platform/security`)
- neuvector (`platform/neuvector` - namespace, CRD and core HelmReleases)
- cluster-config (`platform/cert-manager`)

### 2. Networking Layer

- networking (`platform/networking` - MetalLB, external-dns)
- istio (HelmRelease)
- istio-config (`platform/istio` - Gateways, HTTPRoutes)

### 3. Application Layer

- keycloak (`platform/identity/keycloak`)
- minio (`platform/storage/minio`)

### 4. Observability Layer

- alloy (Grafana Alloy OTLP collector - HelmRelease)
- tempo (`platform/observability/tempo`)
- prometheus (`platform/observability/prometheus`)
- grafana (`platform/observability/grafana`)
- loki (`platform/observability/loki`)

## Gateway API Resources Needed

Each application that is exposed externally needs:

- Gateway (shared main-gateway in istio-system or per-app)
- HTTPRoute
- Service
- Certificate (via cert-manager)
- VirtualService (Istio-specific where used)

## Reference

- Task order: [Taskfile.yml](../../Taskfile.yml) – see `install`, `install:apps`, `install:prerequisites`
- Flux app definitions: [platform/flux/apps/](../../platform/flux/apps/)
