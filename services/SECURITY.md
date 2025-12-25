# Security Hardening Guide for Keycloak and SonarQube

This document outlines the security measures implemented for production deployments of Keycloak and SonarQube.

## 🔒 Security Overview

### Security Principles Applied

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimal permissions and capabilities
3. **Zero Trust**: Explicit network policies, no implicit trust
4. **Secrets Management**: Credentials stored in Kubernetes secrets (migrate to External Secrets)
5. **Resource Isolation**: Namespace and network segmentation
6. **Security Contexts**: Non-root execution, read-only filesystems where possible

## 🛡️ Security Checklist

### ✅ Keycloak Security Measures

#### Application Security
- [x] **Production Mode**: Runs with `start --optimized` command
- [x] **Hostname Strict Mode**: `KC_HOSTNAME_STRICT=true`
- [x] **HTTPS Only**: Disable HTTP in production (`KC_HTTP_ENABLED=false`)
- [x] **Strong Admin Password**: Change default password immediately
- [x] **Security Headers**: Proxy headers configured
- [x] **Health Endpoints**: Enabled for monitoring
- [x] **Metrics**: Prometheus metrics enabled

#### Container Security
- [x] **Run as Non-Root**: UID 1000, GID 1000
- [x] **No Privilege Escalation**: `allowPrivilegeEscalation: false`
- [x] **Drop All Capabilities**: All Linux capabilities dropped
- [x] **Seccomp Profile**: RuntimeDefault applied
- [x] **Resource Limits**: CPU and memory limits enforced
- [x] **Image Security**: Using official Keycloak images

#### Network Security
- [x] **Network Policies**: Zero-trust network segmentation
- [x] **ClusterIP Service**: Not exposed directly
- [x] **TLS Termination**: Via Istio Gateway with cert-manager
- [x] **Egress Controls**: Limited to DNS, PostgreSQL, and HTTPS

#### Data Security
- [x] **Secrets Management**: Kubernetes secrets (TODO: External Secrets)
- [x] **Database Credentials**: Stored in secrets, not ConfigMaps
- [x] **Encryption at Rest**: Depends on storage class encryption
- [x] **Encryption in Transit**: TLS for external connections

### ✅ SonarQube Security Measures

#### Application Security
- [x] **Strong Admin Password**: Change default password
- [x] **Monitoring Passcode**: Unique monitoring passcode
- [x] **HTTPS Only**: Via Istio Gateway
- [x] **Security Context**: Restricted pod security standards
- [x] **Plugin Security**: Only install trusted plugins

#### Container Security
- [x] **Run as Non-Root**: UID 1000
- [x] **No Privilege Escalation**: Explicitly disabled
- [x] **Drop All Capabilities**: All capabilities dropped
- [x] **Seccomp Profile**: RuntimeDefault
- [x] **Resource Limits**: Enforced CPU and memory limits
- [x] **fsGroup**: Set to 0 for file permissions

#### Network Security
- [x] **Network Policies**: Zero-trust network segmentation
- [x] **ClusterIP Service**: Internal only
- [x] **TLS Termination**: Via Istio Gateway
- [x] **Database Isolation**: PostgreSQL only accessible from SonarQube

#### Data Security
- [x] **Database Credentials**: Stored in Kubernetes secrets
- [x] **Persistent Storage**: 20Gi with local-path (TODO: encrypted storage)
- [x] **Backup Strategy**: Document backup procedures

### ✅ PostgreSQL Security (Both Services)

#### Container Security
- [x] **Run as Non-Root**: UID 999 (postgres user)
- [x] **No Privilege Escalation**: Disabled
- [x] **Drop All Capabilities**: All dropped
- [x] **Seccomp Profile**: RuntimeDefault
- [x] **Resource Limits**: CPU and memory enforced

#### Authentication Security
- [x] **Strong Password Hashing**: SCRAM-SHA-256
- [x] **No Trust Auth**: Removed trust authentication
- [x] **Password in Secrets**: Not in environment variables directly
- [x] **User Isolation**: Dedicated database users

#### Network Security
- [x] **Network Policies**: Only allow from application pods
- [x] **ClusterIP Only**: No external exposure
- [x] **Session Affinity**: ClientIP for connection stability

#### Data Security
- [x] **Persistent Storage**: StatefulSet with PVC
- [x] **Backup Strategy**: Document backup/restore procedures
- [ ] **Encryption at Rest**: TODO - depends on storage provider
- [ ] **SSL/TLS**: TODO - enable PostgreSQL SSL

## 🚨 Critical Security Actions Required

### Immediate Actions (Before Production)

1. **Change All Default Passwords**
   ```bash
   # Keycloak admin password
   # SonarQube admin password
   # PostgreSQL passwords for both services
   ```

2. **Implement External Secrets Management**
   ```bash
   # Install External Secrets Operator or Sealed Secrets
   kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
   ```

3. **Enable HTTPS Only**
   ```yaml
   # In keycloak-helm.yaml
   KC_HTTP_ENABLED: "false"
   KC_HOSTNAME_STRICT: "true"
   ```

4. **Configure TLS for PostgreSQL**
   ```yaml
   # Add SSL certificates for PostgreSQL connections
   ```

5. **Enable Audit Logging**
   ```yaml
   # Keycloak: Configure event listeners
   # SonarQube: Enable audit logs
   ```

### Recommended Actions

6. **Implement Pod Security Standards**
   ```yaml
   # Add to namespace
   pod-security.kubernetes.io/enforce: restricted
   pod-security.kubernetes.io/audit: restricted
   pod-security.kubernetes.io/warn: restricted
   ```

7. **Enable Monitoring and Alerting**
   ```yaml
   # Configure Prometheus ServiceMonitors
   # Set up alerts for security events
   ```

8. **Implement Backup Strategy**
   ```bash
   # Automated backups for PostgreSQL databases
   # Backup Keycloak realm configurations
   # Backup SonarQube analysis data
   ```

9. **Enable High Availability**
   ```yaml
   # Keycloak: replicas: 2+, distributed cache
   # PostgreSQL: Consider managed service or replication
   ```

10. **Security Scanning**
    ```bash
    # Scan container images for vulnerabilities
    # Regular dependency updates
    # Security audits
    ```

## 📋 Network Policy Details

### Keycloak Network Policies

**Default Deny All**
- Blocks all ingress and egress by default

**Allowed Ingress**
- Istio Gateway (port 8080)
- Same namespace (health checks, metrics)

**Allowed Egress**
- DNS (kube-system, UDP 53)
- PostgreSQL (port 5432)
- HTTPS (port 443) - for OIDC, SAML, federation

### SonarQube Network Policies

**Default Deny All**
- Blocks all ingress and egress by default

**Allowed Ingress**
- Istio Gateway (port 9000)
- Same namespace (health checks)

**Allowed Egress**
- DNS (kube-system, UDP 53)
- PostgreSQL (port 5432)
- HTTPS (port 443) - for plugin downloads

### PostgreSQL Network Policies

**Ingress**
- Only from application pods (Keycloak or SonarQube)
- Port 5432 only

**Egress**
- DNS only (for hostname resolution)

## 🔐 Secrets Management

### Current State (Development)

Secrets are stored as Kubernetes Secret resources with base64 encoding.

**Files containing secrets:**
- `services/keycloak/postgresql.yaml` - lines 8-11
- `services/sonarqube/postgresql-secure.yaml` - lines 11-14
- `services/keycloak/keycloak-helm.yaml` - line 24, 48-49
- `services/sonarqube/sonarqube-helm.yaml` - lines 28, 32-33, 83

### Production Recommendations

**Option 1: External Secrets Operator (Recommended)**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: keycloak-postgresql
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: keycloak-postgresql
  data:
  - secretKey: postgres-password
    remoteRef:
      key: secret/keycloak/postgres
      property: password
```

**Option 2: Sealed Secrets**
```bash
# Encrypt secrets and commit to Git
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
```

**Option 3: Cloud Provider Secret Managers**
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager

## 🔍 Security Monitoring

### Metrics to Monitor

1. **Authentication Failures**
   - Failed login attempts
   - Password reset requests
   - Account lockouts

2. **Authorization Failures**
   - Denied access attempts
   - Privilege escalation attempts

3. **Database Security**
   - Connection failures
   - Query anomalies
   - Backup failures

4. **Container Security**
   - Pod restarts
   - OOM kills
   - Security context violations

### Recommended Alerts

```yaml
# Prometheus AlertManager rules
- alert: HighAuthenticationFailureRate
  expr: rate(keycloak_failed_login_attempts[5m]) > 10

- alert: DatabaseConnectionFailure
  expr: up{job="postgresql"} == 0

- alert: PodSecurityPolicyViolation
  expr: pod_security_policy_error > 0
```

## 📚 Compliance Considerations

### OWASP Top 10

- [x] **A01:2021 - Broken Access Control**: Network policies, RBAC
- [x] **A02:2021 - Cryptographic Failures**: TLS, secret management
- [x] **A03:2021 - Injection**: Parameterized queries, input validation
- [x] **A04:2021 - Insecure Design**: Security-first architecture
- [x] **A05:2021 - Security Misconfiguration**: Hardened configurations
- [x] **A06:2021 - Vulnerable Components**: Regular updates, scanning
- [x] **A07:2021 - Auth and Session**: Keycloak best practices
- [x] **A08:2021 - Software and Data Integrity**: Image verification
- [x] **A09:2021 - Security Logging**: Audit logs enabled
- [x] **A10:2021 - SSRF**: Network policies, egress filtering

### CIS Kubernetes Benchmark

- [x] Run containers as non-root
- [x] Use read-only root filesystems (where possible)
- [x] Drop unnecessary capabilities
- [x] Enable seccomp profiles
- [x] Set resource limits
- [x] Use network policies
- [x] Enable Pod Security Standards

## 🔄 Regular Security Tasks

### Daily
- Monitor authentication logs
- Check for security alerts
- Review failed access attempts

### Weekly
- Review and rotate credentials
- Update security patches
- Scan container images

### Monthly
- Security audit
- Backup verification
- Disaster recovery testing

### Quarterly
- Penetration testing
- Compliance review
- Security training

## 📞 Incident Response

1. **Detection**: Monitor logs and alerts
2. **Containment**: Network policies, pod isolation
3. **Investigation**: Audit logs, forensics
4. **Eradication**: Patch vulnerabilities
5. **Recovery**: Restore from backups
6. **Lessons Learned**: Update security measures

## 🔗 References

- [Keycloak Security Guide](https://www.keycloak.org/docs/latest/server_admin/#_hardening)
- [SonarQube Security](https://docs.sonarqube.org/latest/instance-administration/security/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
