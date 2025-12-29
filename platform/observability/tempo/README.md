# Grafana Tempo Deployment

This directory provisions Grafana Tempo via the official Helm chart using Kustomize.

## Key Characteristics

- **Namespace**: Deploys into `observability`.
- **Storage**: Uses persistent volumes (`local-path`) for WAL and trace blocks.
- **Receivers**: OTLP gRPC/HTTP enabled; Jaeger/Zipkin disabled.
- **ServiceMonitor**: Enabled for Prometheus scraping.

## Management

- Managed by Flux via `platform/flux/apps/tempo.yaml`.
- Apply manually (if needed) with:
  ```bash
  kubectl apply -k platform/observability/tempo
  ```
- Verify rollout:
  ```bash
  kubectl get pods -n observability -l app.kubernetes.io/name=tempo
  ```

## Integration

- Grafana Alloy forwards OTLP traces to Tempo via
  `tempo-tempo-distributor.observability.svc.cluster.local:4317`.
- Update `values.yaml` to alter storage, scaling, or tenant configuration.

