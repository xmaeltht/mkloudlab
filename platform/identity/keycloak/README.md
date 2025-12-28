# Keycloak Deployment with Flux

This directory contains the Kubernetes manifests to deploy Keycloak, an open-source identity and access management solution. This application is designed to be deployed and managed by Flux CD.

## Overview

Keycloak is deployed using:
- **Codecentric KeycloakX Helm Chart** (v2.5.0)
- **PostgreSQL** as the database backend
- **Istio Gateway** for ingress traffic
- **Cert-Manager** for TLS certificate management
- **Flux HelmRelease** for GitOps deployment

## Prerequisites

- **Flux CD:** Must be installed and running in your cluster
- **Cert-Manager:** Must be installed and configured to issue certificates
- **Istio:** Gateway API controller must be running for ingress
- **Persistent Storage:** `local-path` storage class for PostgreSQL data

## Components

### Files

- `keycloak-helm.yaml`: Flux HelmRelease with Keycloak configuration
- `postgresql.yaml`: PostgreSQL StatefulSet, Service, and Secret for Keycloak database
- `gateway.yaml`: Istio Gateway for external access
- `certificate.yaml`: Cert-Manager Certificate for TLS
- `namespace.yaml`: Keycloak namespace definition
- `kustomization.yaml`: Kustomize configuration for the deployment

### Configuration Details

#### Keycloak Configuration

The Keycloak deployment runs in **production mode** with the following configuration:

**Command:**
```yaml
command:
  - "/opt/keycloak/bin/kc.sh"
  - "start"
  - "--cache=local"
  - "--proxy-headers=xforwarded"
  - "--verbose"
```

**Database:**
- Type: PostgreSQL
- Host: `keycloak-postgresql:5432`
- Database: `keycloak`
- Credentials: Stored in environment variables (see `extraEnv`)

**Proxy Configuration:**
- Proxy mode: `edge` (for reverse proxy deployments)
- HTTP enabled: `true`
- Hostname strict mode: `false` (for development/testing)

**Health Probes:**
- All probes use the root path (`/`) for compatibility
- Startup probe: 10s initial delay, 30 attempts
- Readiness probe: 30s initial delay, 6 failure threshold
- Liveness probe: 120s initial delay, 3 failure threshold

**Admin Credentials:**
- Username: `admin`
- Password: `Keycloak123!` (⚠️ Change after first login!)

#### PostgreSQL Configuration

- Image: `postgres:15-alpine`
- Storage: 10Gi persistent volume with `local-path` storage class
- Resources:
  - Requests: 200m CPU, 256Mi memory
  - Limits: 500m CPU, 512Mi memory

## Deployment via Flux

Flux automatically deploys Keycloak when the manifests are committed to the Git repository. The HelmRelease will be reconciled every 5 minutes.

### Manual Reconciliation

To trigger an immediate reconciliation:

```bash
flux reconcile helmrelease keycloak -n keycloak
```

### Check Deployment Status

```bash
# Check HelmRelease status
kubectl get helmrelease -n keycloak keycloak

# Check pods
kubectl get pods -n keycloak

# Check logs
kubectl logs -n keycloak keycloak-keycloak-keycloakx-0 -c keycloak
```

## Accessing Keycloak

After deployment, Keycloak will be accessible at the hostname specified in `gateway.yaml` (e.g., `keycloak.mkloud.lab`).

### Port-Forward for Local Access

```bash
kubectl port-forward -n keycloak svc/keycloak-keycloak-keycloakx-http 8080:8080
```

Then access Keycloak at: http://localhost:8080

## Troubleshooting

### Pod CrashLoopBackOff

If the Keycloak pod is crash-looping, check:

1. **Command configuration**: Ensure the `command` array in `keycloak-helm.yaml` is correctly set
2. **Database connectivity**: Verify PostgreSQL is running and accessible
3. **Health probe paths**: Ensure probe paths are compatible with the Keycloak version

### Health Probes Failing

If health probes are failing with 404 errors:

1. Verify the probe paths match available endpoints
2. Check Istio sidecar is not interfering with health checks
3. Increase `initialDelaySeconds` to allow more startup time

### Database Connection Issues

If Keycloak cannot connect to PostgreSQL:

1. Verify the PostgreSQL pod is running: `kubectl get pods -n keycloak`
2. Check the database credentials in the secret
3. Verify the service DNS resolution: `kubectl get svc -n keycloak`

## Security Considerations

⚠️ **Important Security Notes:**

1. **Change Default Password:** The default admin password `Keycloak123!` should be changed immediately after first login
2. **Enable HTTPS:** In production, ensure TLS is properly configured via cert-manager
3. **Database Credentials:** Consider using external secrets management for sensitive data
4. **Hostname Configuration:** Enable strict hostname checking (`KC_HOSTNAME_STRICT=true`) in production

## Configuration Updates

To update the Keycloak configuration:

1. Edit `keycloak-helm.yaml`
2. Commit and push changes to Git
3. Flux will automatically reconcile the changes
4. Or manually trigger: `flux reconcile helmrelease keycloak -n keycloak`

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Codecentric KeycloakX Helm Chart](https://github.com/codecentric/helm-charts/tree/master/charts/keycloakx)
- [Flux CD Documentation](https://fluxcd.io/docs/)
