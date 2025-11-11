# Grafana Alloy Collector

This directory defines the production-ready Grafana Alloy deployment used to collect
metrics, logs, and traces from the cluster.

## Components

- `kustomization.yaml` – bundles the resources and generates the Alloy configuration ConfigMap.
- `alloy-daemonset.yaml` – Namespace, RBAC, DaemonSet, Service, and disruption budget.
- `config/alloy.river` – The Alloy pipeline (OTLP receiver, Prometheus remote write, Loki log shipping).

## Key Behaviours

- **Deployment model**: DaemonSet ensures each node tails container logs and scrapes local exporters.
- **OTLP endpoints**: Exposed via the `alloy-gateway` Service on ports 4317 (gRPC) and 4318 (HTTP).
- **Metrics**: Forwarded to in-cluster Prometheus via remote write.
- **Logs**: Shipped to the existing Loki stack.
- **Traces**: Forwarded to Grafana Tempo via the internal service `tempo-tempo-distributor.observability.svc.cluster.local:4317`.

## Operations

- Configuration changes are managed by editing `config/alloy.river`.
- Apply with ArgoCD (`platform/argocd/apps/alloy-app.yaml`) or manually via `kubectl apply -k platform/observability/alloy`.
- Review Alloy health from the `/ -/ready` probe on port 12345 exposed inside the pod.
- Metrics scraped from Alloy itself are available on `/metrics` (port 12345) and picked up by Prometheus via ServiceMonitors.

## TODO

- Expand Prometheus scrape jobs (`discovery.kubernetes`) for application pods as instrumentation coverage grows.

