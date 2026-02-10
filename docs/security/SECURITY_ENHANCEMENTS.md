# Security Enhancements Documentation

This document outlines the security improvements implemented in the Mkloudlab Kubernetes GitOps repository.

## 🔒 Security Features Implemented

### 1. Pod Security Standards (PSS)

**Location**: `platform/security/namespace-security.yaml`

All namespaces now implement Pod Security Standards with appropriate enforcement levels:

- **Restricted**: `observability`
- **Baseline**: `kyverno`, `cert-manager`
- **Privileged** (for Istio mesh): `keycloak`

**Benefits**:

- Prevents privileged containers
- Enforces non-root user execution
- Restricts host namespace access
- Improves overall security posture

### 2. External Secrets Operator

**Location**: `platform/external-secrets/` (Flux Kustomization: `platform/flux/apps/external-secrets.yaml`)

Secure secrets management without storing sensitive data in Git:

- Integrates with external secret stores (AWS Secrets Manager, HashiCorp Vault, etc.)
- Automatic secret rotation
- RBAC-controlled access
- Audit logging

**Usage**:

```bash
# Check external secrets status
task secrets:status

# View external secrets
kubectl get externalsecrets -A
```

### 3. Enhanced Network Policies

**Location**: `platform/security/network-policies.yaml` and `platform/observability/network-policies.yaml`

Comprehensive micro-segmentation with:

- Default deny-all policies
- DNS access policies
- Service-specific ingress/egress rules
- Namespace-level isolation

**Features**:

- Blocks unnecessary network communication
- Allows only required ports and protocols
- Implements zero-trust networking principles
- New policy for Grafana Alloy limits OTLP ingress to approved namespaces and constrains egress to Prometheus/Loki endpoints.
- Additional policy for Grafana Tempo restricts trace ingestion to Alloy and observability tooling while tightening inter-component traffic.

### 4. Comprehensive RBAC Policies

**Location**: `platform/security/rbac-policies.yaml`

Fine-grained access control with:

- Service-specific roles and bindings
- Minimal privilege principle
- Component-specific permissions
- Audit-ready configurations

**Service Accounts Created**:

- `monitoring-reader`: Observability access
- `security-scanner`: Security operations
- `alloy`: Grafana Alloy daemonset (cluster log/metric collection)
- `tempo`: Grafana Tempo components (trace ingestion & query)

### 5. Enhanced Monitoring & Alerting

**Location**: `platform/observability/prometheus/` and `platform/observability/grafana/` (Flux: `platform/flux/apps/prometheus.yaml`, `platform/flux/apps/grafana.yaml`)

Improved observability with:

- **Alertmanager enabled**: Comprehensive alerting
- **Additional exporters**: kube-state-metrics, node-exporter
- **Custom scrape configs**: Pod-level metrics collection
- **Persistent storage**: Alert history retention

### 6. Centralized Logging

**Location**: `platform/observability/loki/` (Flux: `platform/flux/apps/loki.yaml`). Alloy (OTLP collector) replaces Promtail for log collection.

Centralized log management with:

- **Loki**: Log aggregation and storage
- **Grafana Alloy**: OTLP and log collection from workloads
- **Grafana**: Log visualization and analysis
- **Persistent storage**: Log retention

## 🛠 New Taskfile Commands

### Security Operations

```bash
# Run comprehensive security scan
task security:scan

# Validate security configurations
task security:validate

# Check external secrets status
task secrets:status
```

### Enhanced Health Checks

```bash
# Comprehensive health check (now includes security status)
task health
```

## 📊 Security Metrics

The enhanced monitoring now tracks:

- Network policy violations
- Pod security standard compliance
- RBAC permission usage
- Secret access patterns
- Security event logs

## 🔧 Configuration Management

### Security Configuration Application

**Location**: `platform/flux/apps/security-config.yaml` (Flux Kustomization pointing to `platform/security/`)

Automatically deploys all security configurations:

- Namespace security labels
- Network policies
- RBAC policies
- Resource quotas and limits

## 🚀 Deployment Instructions

### 1. Deploy Security Enhancements

```bash
# Install the enhanced stack
task install

# Verify security configurations
task security:validate

# Run security scan
task security:scan
```

### 2. Configure External Secrets

After deployment, configure external secret stores:

```bash
# Create secret store (example for AWS)
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        secretRef:
          accessKeyID:
            name: aws-credentials
            key: access-key
          secretAccessKey:
            name: aws-credentials
            key: secret-key
EOF
```

### 3. Verify Security Status

```bash
# Check all security components
task health

# View network policies
kubectl get networkpolicies -A

# Check Pod Security Standards
kubectl get namespaces -o custom-columns=NAME:.metadata.name,PSS-ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce
```

## 🔍 Troubleshooting

### Common Issues

1. **Pod Security Violations**

   ```bash
   # Check pod security events
   kubectl get events --field-selector reason=FailedCreate
   ```

2. **Network Policy Blocking Traffic**

   ```bash
   # Check network policy status
   kubectl describe networkpolicy <policy-name> -n <namespace>
   ```

3. **RBAC Permission Denied**
   ```bash
   # Check service account permissions
   kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<service-account>
   ```

## 📈 Next Steps

### Recommended Enhancements

1. **Service Mesh Integration**: Add Istio for advanced traffic management
2. **Image Scanning**: Implement Trivy or similar for container image security
3. **Compliance Scanning**: Add CIS Kubernetes Benchmark checks
4. **Secrets Rotation**: Implement automatic secret rotation policies
5. **Multi-Environment**: Create dev/staging/prod security profiles

### Monitoring Improvements

1. **Custom Dashboards**: Create security-specific Grafana dashboards
2. **Alert Rules**: Define comprehensive alerting rules for security events
3. **Log Analysis**: Set up log-based security monitoring
4. **Compliance Reporting**: Generate security compliance reports

## 📚 Additional Resources

- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
