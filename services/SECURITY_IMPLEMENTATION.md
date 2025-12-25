# Security Implementation Plan

## 🎯 Objective

Implement production-grade security measures for Keycloak and SonarQube deployments.

## 📊 Current State vs. Security-Hardened Configuration

### Configuration Files Comparison

| Component | Current File | Security-Hardened File | Status |
|-----------|--------------|------------------------|---------|
| Keycloak | `keycloak-helm.yaml` | `keycloak-helm-secure.yaml` | ✅ Created |
| Keycloak PostgreSQL | `postgresql.yaml` | `postgresql-secure.yaml` | ✅ Created |
| Keycloak Network Policy | N/A | `network-policy.yaml` | ✅ Created |
| SonarQube | `sonarqube-helm.yaml` | Update in-place | ⏳ Pending |
| SonarQube PostgreSQL | `postgresql.yaml` | `postgresql-secure.yaml` | ✅ Created |
| SonarQube Network Policy | N/A | `network-policy.yaml` | ✅ Created |

### Key Differences

#### Current Configuration Issues

**Keycloak:**
- ❌ Running in development mode (`start-dev`)
- ❌ Hardcoded passwords in YAML
- ❌ No security context
- ❌ No resource limits
- ❌ No network policies
- ❌ Hostname strict mode disabled
- ❌ HTTP enabled

**PostgreSQL (Both Services):**
- ❌ No security context (running as root)
- ❌ Weak password hashing (MD5)
- ❌ No resource limits
- ❌ No network policies
- ❌ Secrets in plaintext

#### Security-Hardened Configuration

**Keycloak:**
- ✅ Production mode with `--optimized`
- ✅ Secrets referenced from Kubernetes secrets
- ✅ Security context (non-root, dropped capabilities)
- ✅ Resource limits enforced
- ✅ Zero-trust network policies
- ✅ Hostname strict mode enabled
- ✅ TLS/HTTPS only in production
- ✅ Seccomp profile applied

**PostgreSQL (Both Services):**
- ✅ Security context (UID 999, non-root)
- ✅ SCRAM-SHA-256 password hashing
- ✅ Resource limits enforced
- ✅ Network policies (ingress from app only)
- ✅ Dropped all capabilities
- ✅ Seccomp profile
- ✅ Read-only root filesystem where possible

## 🚀 Implementation Steps

### Phase 1: Pre-Deployment Preparation (Security Audit)

1. **Review Current Configuration**
   ```bash
   # Check current Keycloak mode
   kubectl logs -n keycloak keycloak-keycloak-keycloakx-0 -c keycloak | grep -i "profile\|mode"

   # Check current security contexts
   kubectl get pod -n keycloak keycloak-keycloak-keycloakx-0 -o jsonpath='{.spec.securityContext}'
   kubectl get pod -n sonarqube sonarqube-sonarqube-sonarqube-0 -o jsonpath='{.spec.securityContext}'
   ```

2. **Backup Current Configurations**
   ```bash
   kubectl get helmrelease -n keycloak keycloak -o yaml > keycloak-backup.yaml
   kubectl get helmrelease -n sonarqube sonarqube -o yaml > sonarqube-backup.yaml
   kubectl get secret -n keycloak keycloak-postgresql -o yaml > keycloak-secret-backup.yaml
   kubectl get secret -n sonarqube sonarqube-sonarqube-postgresql -o yaml > sonarqube-secret-backup.yaml
   ```

3. **Generate Strong Passwords**
   ```bash
   # Generate secure passwords
   openssl rand -base64 32  # For Keycloak admin
   openssl rand -base64 32  # For Keycloak PostgreSQL
   openssl rand -base64 32  # For SonarQube admin
   openssl rand -base64 32  # For SonarQube PostgreSQL
   openssl rand -base64 32  # For SonarQube monitoring
   ```

### Phase 2: Update Secrets (Do This First!)

1. **Update Keycloak PostgreSQL Secret**
   ```bash
   # Edit the secure configuration with your passwords
   vi services/keycloak/postgresql-secure.yaml

   # Replace placeholders:
   # - CHANGE_ME_USE_STRONG_PASSWORD → your generated password

   # Apply the new secret (will update existing)
   kubectl apply -f services/keycloak/postgresql-secure.yaml
   ```

2. **Update SonarQube PostgreSQL Secret**
   ```bash
   # Edit the secure configuration
   vi services/sonarqube/postgresql-secure.yaml

   # Replace placeholders
   # Apply
   kubectl apply -f services/sonarqube/postgresql-secure.yaml
   ```

3. **Update Application Passwords**
   ```bash
   # Update Keycloak admin password in keycloak-helm-secure.yaml
   vi services/keycloak/keycloak-helm-secure.yaml
   # Replace: CHANGE_ME_IMMEDIATELY

   # Update SonarQube credentials
   # (SonarQube uses secrets via helm values - update after deployment)
   ```

### Phase 3: Deploy Network Policies

**Important:** Deploy network policies AFTER verifying application connectivity!

1. **Test Current Connectivity**
   ```bash
   # Ensure applications are working
   kubectl get pods -n keycloak
   kubectl get pods -n sonarqube
   ```

2. **Apply Network Policies**
   ```bash
   # Apply Keycloak network policies
   kubectl apply -f services/keycloak/network-policy.yaml

   # Verify Keycloak still works
   kubectl get pods -n keycloak
   kubectl logs -n keycloak keycloak-keycloak-keycloakx-0 -c keycloak --tail=20

   # Apply SonarQube network policies
   kubectl apply -f services/sonarqube/network-policy.yaml

   # Verify SonarQube still works
   kubectl get pods -n sonarqube
   ```

3. **Test Network Policies**
   ```bash
   # Test that unauthorized access is blocked
   kubectl run -it --rm debug --image=alpine --restart=Never -n default -- sh
   # Inside the pod, try: wget -O- http://keycloak-keycloak-keycloakx-http.keycloak:8080
   # Should timeout or be denied
   ```

### Phase 4: Deploy Keycloak Security-Hardened Configuration

**Note:** Keycloak requires a build step for production mode. Options:

**Option A: Use Custom Init Container (Recommended)**
```yaml
initContainers:
- name: keycloak-build
  image: quay.io/keycloak/keycloak:25.0.0
  command:
    - /opt/keycloak/bin/kc.sh
    - build
    - --cache=local
    - --health-enabled=true
    - --metrics-enabled=true
  volumeMounts:
    - name: keycloak-data
      mountPath: /opt/keycloak/data
```

**Option B: Use Pre-Built Custom Image**
```dockerfile
FROM quay.io/keycloak/keycloak:25.0.0 as builder
RUN /opt/keycloak/bin/kc.sh build --cache=local --health-enabled=true --metrics-enabled=true

FROM quay.io/keycloak/keycloak:25.0.0
COPY --from=builder /opt/keycloak/ /opt/keycloak/
```

**Option C: Stay with Start-Dev but Harden**
For development/testing environments:
```yaml
args:
  - "start-dev"
  - "--cache=local"
  - "--proxy-headers=xforwarded"
```

**Deployment Steps:**

1. **Suspend Flux**
   ```bash
   flux suspend helmrelease keycloak -n keycloak
   ```

2. **Choose Your Approach** (A, B, or C above)

3. **For Option C (Hardened Dev Mode):**
   ```bash
   # Update keycloak-helm-secure.yaml to use start-dev with security hardening
   # Then apply
   helm upgrade keycloak-keycloak codecentric/keycloakx --version 2.5.0 \\
     -n keycloak \\
     -f services/keycloak/keycloak-helm-secure.yaml
   ```

4. **Restart Pod**
   ```bash
   kubectl delete pod keycloak-keycloak-keycloakx-0 -n keycloak
   ```

5. **Verify**
   ```bash
   # Check mode
   kubectl logs -n keycloak keycloak-keycloak-keycloakx-0 -c keycloak | grep -i "profile\|mode"

   # Check security context
   kubectl get pod keycloak-keycloak-keycloakx-0 -n keycloak \\
     -o jsonpath='{.spec.securityContext}'

   # Check health
   kubectl get pods -n keycloak
   ```

### Phase 5: Deploy SonarQube Security Updates

1. **Update SonarQube HelmRelease**
   ```bash
   # Update sonarqube-helm.yaml with:
   # - Secrets from Kubernetes secrets (not hardcoded)
   # - Ensure security context is present

   # Apply via Flux or manually
   kubectl apply -f services/sonarqube/sonarqube-helm.yaml
   ```

2. **Verify**
   ```bash
   kubectl get pods -n sonarqube
   kubectl get pod sonarqube-sonarqube-sonarqube-0 -n sonarqube \\
     -o jsonpath='{.spec.securityContext}'
   ```

### Phase 6: Enable Additional Security Features

1. **Enable Pod Security Standards**
   ```bash
   # Add labels to namespaces
   kubectl label namespace keycloak \\
     pod-security.kubernetes.io/enforce=restricted \\
     pod-security.kubernetes.io/audit=restricted \\
     pod-security.kubernetes.io/warn=restricted

   kubectl label namespace sonarqube \\
     pod-security.kubernetes.io/enforce=restricted \\
     pod-security.kubernetes.io/audit=restricted \\
     pod-security.kubernetes.io/warn=restricted
   ```

2. **Enable Resource Quotas**
   ```yaml
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: keycloak-quota
     namespace: keycloak
   spec:
     hard:
       requests.cpu: "4"
       requests.memory: 8Gi
       limits.cpu: "8"
       limits.memory: 16Gi
   ```

3. **Configure HTTPS Only**
   ```bash
   # Update Keycloak configuration
   # Set KC_HTTP_ENABLED=false
   # Ensure Istio Gateway has TLS configured
   ```

### Phase 7: Monitoring and Validation

1. **Setup Monitoring**
   ```bash
   # Create ServiceMonitor for Prometheus
   kubectl apply -f monitoring/keycloak-servicemonitor.yaml
   kubectl apply -f monitoring/sonarqube-servicemonitor.yaml
   ```

2. **Run Security Scan**
   ```bash
   # Scan images for vulnerabilities
   trivy image quay.io/keycloak/keycloak:25.0.0
   trivy image sonarqube:10.7.0-community
   trivy image postgres:15-alpine
   ```

3. **Validate Security Configurations**
   ```bash
   # Check security contexts
   kubectl get pod -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}'

   # Check network policies
   kubectl get networkpolicy -A

   # Check resource limits
   kubectl describe limitrange -A
   ```

## 📋 Post-Implementation Checklist

- [ ] All passwords changed from defaults
- [ ] Secrets stored in Kubernetes secrets (not YAML)
- [ ] Security contexts applied to all containers
- [ ] Resource limits set for all containers
- [ ] Network policies deployed and tested
- [ ] Keycloak running in production mode (or hardened dev mode)
- [ ] PostgreSQL using SCRAM-SHA-256
- [ ] HTTPS/TLS enabled for external access
- [ ] Pod Security Standards enforced
- [ ] Monitoring and alerting configured
- [ ] Backup strategy implemented
- [ ] Documentation updated
- [ ] Security audit completed

## 🔄 Rollback Procedure

If issues occur:

1. **Suspend Flux**
   ```bash
   flux suspend helmrelease keycloak -n keycloak
   flux suspend helmrelease sonarqube -n sonarqube
   ```

2. **Rollback Helm Releases**
   ```bash
   helm rollback keycloak-keycloak -n keycloak
   helm rollback sonarqube-sonarqube -n sonarqube
   ```

3. **Remove Network Policies** (if causing issues)
   ```bash
   kubectl delete networkpolicy -n keycloak --all
   kubectl delete networkpolicy -n sonarqube --all
   ```

4. **Restore Secrets** (if needed)
   ```bash
   kubectl apply -f keycloak-secret-backup.yaml
   kubectl apply -f sonarqube-secret-backup.yaml
   ```

5. **Restart Pods**
   ```bash
   kubectl delete pod -n keycloak --all
   kubectl delete pod -n sonarqube --all
   ```

## 📞 Support and References

- Security Documentation: `services/SECURITY.md`
- Keycloak Security Guide: https://www.keycloak.org/docs/latest/server_admin/#_hardening
- Kubernetes Security Best Practices: https://kubernetes.io/docs/concepts/security/
- CIS Benchmarks: https://www.cisecurity.org/benchmark/kubernetes

## ⚠️ Important Notes

1. **Test in Non-Production First**: Always test security changes in a development environment
2. **Backup Before Changes**: Always backup configurations and data
3. **Monitor After Changes**: Watch logs and metrics for issues
4. **Document Changes**: Keep track of all security configurations
5. **Regular Reviews**: Security is ongoing, not one-time

## 🎓 Training Requirements

Ensure team members understand:
- Kubernetes security contexts
- Network policy concepts
- Secrets management
- Incident response procedures
- Backup and restore procedures
