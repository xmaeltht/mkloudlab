# SonarQube Deployment with Flux

This directory contains the Kubernetes manifests to deploy SonarQube, an open-source platform for continuous inspection of code quality. This application is designed to be deployed and managed by Flux CD.

## Overview

SonarQube is deployed using:
- **SonarQube Official Helm Chart** (v10.7.0)
- **PostgreSQL** as the database backend
- **Istio Gateway** for ingress traffic
- **Cert-Manager** for TLS certificate management
- **Flux HelmRelease** for GitOps deployment

## Prerequisites

- **Flux CD:** Must be installed and running in your cluster
- **Cert-Manager:** Must be installed and configured to issue certificates
- **Istio:** Gateway API controller must be running for ingress
- **Persistent Storage:** `local-path` storage class for SonarQube data and PostgreSQL

## Components

### Files

- `sonarqube-helm.yaml`: Flux HelmRelease with SonarQube configuration
- `postgresql.yaml`: PostgreSQL StatefulSet, Service, and Secret for SonarQube database
- `gateway.yaml`: Istio Gateway for external access
- `certificate.yaml`: Cert-Manager Certificate for TLS
- `namespace.yaml`: SonarQube namespace definition
- `kustomization.yaml`: Kustomize configuration for the deployment

### Configuration Details

#### SonarQube Configuration

The SonarQube deployment runs in **Community Edition** with the following configuration:

**Edition:**
- Community Edition (free and open-source)

**Database:**
- Type: PostgreSQL 15
- Host: `sonarqube-postgresql:5432`
- Database: `sonarDB`
- Username: `sonarUser`
- Password: `SonarQube123!` (⚠️ Change after first login!)
- **Secret Name:** `sonarqube-sonarqube-postgresql` (important for Helm chart compatibility)

**Storage:**
- Size: 20Gi persistent volume
- Storage Class: `local-path`
- Access Mode: ReadWriteOnce

**Resources:**
- Requests: 400m CPU, 2048Mi memory
- Limits: 800m CPU, 6144Mi memory

**JVM Options:**
- Main JVM: `-Xmx2G -Xms512m`
- Compute Engine: `-Xmx512m -Xms128m`

**Security:**
- Running as non-root user (UID 1000)
- No privilege escalation
- All capabilities dropped
- Seccomp profile: RuntimeDefault

**Health Probes:**
- Readiness probe: 60s initial delay, 30s period, 6 failure threshold
- Liveness probe: 60s initial delay, 30s period, 6 failure threshold
- Monitoring passcode: `SonarQube123!`

**Admin Credentials:**
- Default Username: `admin`
- Default Password: `admin` (initially)
- New Password: `SonarQube123!` (⚠️ Change after first login!)

#### PostgreSQL Configuration

- Image: `postgres:15-alpine`
- Storage: 10Gi persistent volume with `local-path` storage class
- Resources:
  - Requests: 200m CPU, 256Mi memory
  - Limits: 500m CPU, 512Mi memory
- **Secret:** `sonarqube-sonarqube-postgresql` (matches Helm chart naming convention)

## Important: PostgreSQL Secret Naming

⚠️ **Critical Configuration Detail:**

The PostgreSQL secret must be named `sonarqube-sonarqube-postgresql` (not `sonarqube-postgresql`) to match the SonarQube Helm chart's naming convention. The chart automatically prefixes resources with the release name.

This naming is crucial for:
- The SonarQube pod to find the database credentials
- Proper Helm chart integration
- Avoiding `CreateContainerConfigError` issues

## Deployment via Flux

Flux automatically deploys SonarQube when the manifests are committed to the Git repository. The HelmRelease will be reconciled every 5 minutes.

### Manual Reconciliation

To trigger an immediate reconciliation:

```bash
flux reconcile helmrelease sonarqube -n sonarqube
```

### Check Deployment Status

```bash
# Check HelmRelease status
kubectl get helmrelease -n sonarqube sonarqube

# Check pods
kubectl get pods -n sonarqube

# Check logs
kubectl logs -n sonarqube sonarqube-sonarqube-sonarqube-0 -c sonarqube
```

## Accessing SonarQube

After deployment, SonarQube will be accessible at the hostname specified in `gateway.yaml` (e.g., `sonarqube.mkloud.lab`).

### Port-Forward for Local Access

```bash
kubectl port-forward -n sonarqube svc/sonarqube-sonarqube-sonarqube 9000:9000
```

Then access SonarQube at: http://localhost:9000

### First Login

1. Navigate to the SonarQube URL
2. Login with username `admin` and password `admin`
3. You'll be prompted to change the password
4. Set the new password to match the configured `adminPassword` or your preferred secure password

## Troubleshooting

### Pod CreateContainerConfigError

If the SonarQube pod shows `CreateContainerConfigError`:

1. **Check secret name**: Ensure the PostgreSQL secret is named `sonarqube-sonarqube-postgresql`
2. **Verify secret exists**: `kubectl get secret -n sonarqube sonarqube-sonarqube-postgresql`
3. **Check secret keys**: The secret must contain `postgres-user`, `postgres-password`, and `postgres-db`

### Database Connection Issues

If SonarQube cannot connect to PostgreSQL:

1. Verify the PostgreSQL pod is running: `kubectl get pods -n sonarqube`
2. Check PostgreSQL logs: `kubectl logs -n sonarqube sonarqube-postgresql-0`
3. Verify the secret values match the database configuration
4. Check service DNS resolution: `kubectl get svc -n sonarqube`

### Performance Issues

If SonarQube is slow or OOM (Out of Memory):

1. **Increase JVM memory**: Adjust `jvmOpts` in `sonarqube-helm.yaml`
2. **Increase resource limits**: Modify `resources.limits.memory`
3. **Check database performance**: PostgreSQL may need more resources
4. **Review SonarQube logs**: Look for garbage collection or memory warnings

### Health Probe Failures

If health probes are failing:

1. Verify monitoring passcode is set correctly
2. Increase `initialDelaySeconds` for slower startup
3. Check SonarQube logs for startup errors
4. Verify database connectivity

## Security Considerations

⚠️ **Important Security Notes:**

1. **Change Default Passwords:**
   - Admin password: Change from default `admin` on first login
   - Database password: Update `SonarQube123!` to a secure password
   - Monitoring passcode: Update in production environments

2. **Enable HTTPS:** In production, ensure TLS is properly configured via cert-manager

3. **Database Credentials:** Consider using external secrets management (e.g., External Secrets Operator, Sealed Secrets)

4. **Network Policies:** Implement network policies to restrict traffic to SonarQube

5. **Regular Updates:** Keep SonarQube and PostgreSQL updated for security patches

## Configuration Updates

To update the SonarQube configuration:

1. Edit `sonarqube-helm.yaml`
2. Commit and push changes to Git
3. Flux will automatically reconcile the changes
4. Or manually trigger: `flux reconcile helmrelease sonarqube -n sonarqube`

## Common Operations

### Restart SonarQube

```bash
kubectl rollout restart statefulset/sonarqube-sonarqube-sonarqube -n sonarqube
```

### Restart PostgreSQL

```bash
kubectl rollout restart statefulset/sonarqube-postgresql -n sonarqube
```

### View SonarQube Logs

```bash
kubectl logs -n sonarqube -f sonarqube-sonarqube-sonarqube-0 -c sonarqube
```

### Access Database

```bash
kubectl exec -it -n sonarqube sonarqube-postgresql-0 -- psql -U sonarUser -d sonarDB
```

## Backup and Restore

### Backup Database

```bash
kubectl exec -n sonarqube sonarqube-postgresql-0 -- \
  pg_dump -U sonarUser sonarDB > sonarqube-backup.sql
```

### Restore Database

```bash
kubectl exec -i -n sonarqube sonarqube-postgresql-0 -- \
  psql -U sonarUser sonarDB < sonarqube-backup.sql
```

## References

- [SonarQube Documentation](https://docs.sonarqube.org/latest/)
- [SonarQube Helm Chart](https://github.com/SonarSource/helm-chart-sonarqube)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
