# Maintenance Runbook

## 🔧 Maintenance Overview

This runbook covers routine maintenance tasks for the Mkloudlab Kubernetes GitOps environment, including updates, backups, monitoring, and optimization.

## 📅 Maintenance Schedule

### Daily Tasks

- [ ] **Health check**: `task health`
- [ ] **Application status**: `task status`
- [ ] **Security scan**: `task security:scan`
- [ ] **Certificate status**: `task certs:status`

### Weekly Tasks

- [ ] **Resource usage review**: `kubectl top nodes`
- [ ] **Log analysis**: Check for errors and warnings
- [ ] **Backup verification**: Ensure backups are working
- [ ] **Security validation**: `task security:validate`

### Monthly Tasks

- [ ] **Certificate renewal check**: Verify auto-renewal
- [ ] **Resource optimization**: Review and adjust limits
- [ ] **Security updates**: Update base images and policies
- [ ] **Documentation review**: Update runbooks and docs

### Quarterly Tasks

- [ ] **Cluster upgrade planning**: Review Kubernetes versions
- [ ] **Disaster recovery testing**: Test backup/restore procedures
- [ ] **Security audit**: Comprehensive security review
- [ ] **Performance optimization**: Review and optimize configurations

## 🔄 Update Procedures

### Application Updates

#### 1. ArgoCD Updates

```bash
# Check current ArgoCD version
kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}'

# Update ArgoCD (modify argocd/manifests/argocd-values.yaml)
# Change the image tag to new version

# Apply update
kubectl apply -n argocd -f argocd/manifests/argocd-values.yaml

# Verify update
kubectl rollout status deployment/argocd-server -n argocd
```

#### 2. Application Updates

```bash
# Update application manifests in Git
# ArgoCD will automatically sync changes

# Force sync if needed
task argocd:sync

# Monitor update progress
watch kubectl get applications -n argocd
```

#### 3. Base Image Updates

```bash
# Update base images in manifests
# Example: Update Keycloak image
kubectl patch statefulset keycloak -n keycloak -p '{"spec":{"template":{"spec":{"containers":[{"name":"keycloak","image":"quay.io/keycloak/keycloak:latest"}]}}}}'

# Verify update
kubectl rollout status statefulset/keycloak -n keycloak
```

#### 4. Grafana Alloy Upgrades

```bash
# Bump Alloy version in manifests
vim platform/observability/alloy/alloy-daemonset.yaml

# Apply via kustomize
kubectl apply -k platform/observability/alloy

# Confirm rollout
kubectl rollout status daemonset/alloy-agent -n observability
```

#### 5. Grafana Tempo Upgrades

```bash
# Update Helm values / chart version
vim platform/observability/tempo/kustomization.yaml
vim platform/observability/tempo/values.yaml

# Apply via kustomize
kubectl apply -k platform/observability/tempo

# Confirm rollout
kubectl rollout status statefulset/tempo-ingester -n observability
kubectl rollout status deployment/tempo-query-frontend -n observability
```

### Security Updates

#### 1. Pod Security Standards Updates

```bash
# Review current PSS configuration
kubectl get namespaces -o custom-columns=NAME:.metadata.name,PSS-ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce

# Update PSS in security/namespace-security.yaml
# Apply changes
kubectl apply -f security/namespace-security.yaml
```

#### 2. Network Policy Updates

```bash
# Review current network policies
kubectl get networkpolicies -A

# Update policies in security/network-policies.yaml
# Apply changes
kubectl apply -f security/network-policies.yaml
```

#### 3. RBAC Updates

```bash
# Review current RBAC
kubectl get roles,clusterroles,rolebindings,clusterrolebindings -A

# Update RBAC in security/rbac-policies.yaml
# Apply changes
kubectl apply -f security/rbac-policies.yaml
```

## 💾 Backup Procedures

### 1. Cluster State Backup

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d-%H%M%S)

# Backup all resources
kubectl get all -A -o yaml > backups/$(date +%Y%m%d-%H%M%S)/cluster-state.yaml

# Backup persistent volumes
kubectl get pv,pvc -A -o yaml > backups/$(date +%Y%m%d-%H%M%S)/persistent-volumes.yaml

# Backup secrets
kubectl get secrets -A -o yaml > backups/$(date +%Y%m%d-%H%M%S)/secrets.yaml

# Backup configurations
kubectl get configmaps -A -o yaml > backups/$(date +%Y%m%d-%H%M%S)/configmaps.yaml
```

### 2. ArgoCD Backup

```bash
# Backup ArgoCD applications
kubectl get applications -n argocd -o yaml > backups/$(date +%Y%m%d-%H%M%S)/argocd-applications.yaml

# Backup ArgoCD configuration
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml > backups/$(date +%Y%m%d-%H%M%S)/argocd-config.yaml
```

### 4. Git Repository Backup

```bash
# Backup Git repository
git bundle create backup-$(date +%Y%m%d).bundle --all

# Verify backup
git bundle verify backup-$(date +%Y%m%d).bundle
```

## 🔍 Monitoring Maintenance

### 1. Prometheus Maintenance

```bash
# Check Prometheus status
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check Prometheus configuration
kubectl get configmap prometheus-server -n monitoring -o yaml

# Check Prometheus targets
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
# Open http://localhost:9090/targets
```

### 2. Grafana Maintenance

```bash
# Check Grafana status
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Backup Grafana dashboards
kubectl exec -it <grafana-pod> -n monitoring -- grafana-cli admin export-dashboard <dashboard-id> > dashboard.json

# Restore Grafana dashboards
kubectl exec -it <grafana-pod> -n monitoring -- grafana-cli admin import-dashboard dashboard.json
```

### 3. Alertmanager Maintenance

```bash
# Check Alertmanager status
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# Check Alertmanager configuration
kubectl get configmap alertmanager -n monitoring -o yaml

# Test alerting
kubectl port-forward svc/alertmanager -n monitoring 9093:80
# Open http://localhost:9093
```

### 4. Loki Maintenance

```bash
# Check Loki status
kubectl get pods -n logging -l app.kubernetes.io/name=loki

# Check Loki configuration
kubectl get configmap loki -n logging -o yaml

# Check log retention
kubectl exec -it <loki-pod> -n logging -- loki --config.file=/etc/loki/local-config.yaml
```

## 🔧 Performance Optimization

### 1. Resource Optimization

```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check resource quotas
kubectl get resourcequota -A

# Optimize resource requests
kubectl patch deployment <deployment-name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"requests":{"cpu":"100m","memory":"128Mi"}}}]}}}}'
```

### 2. Storage Optimization

```bash
# Check storage usage
kubectl get pv,pvc -A

# Check storage class
kubectl get storageclass

# Clean up unused volumes
kubectl get pv | grep Released | awk '{print $1}' | xargs kubectl delete pv
```

### 3. Network Optimization

```bash
# Check network policies
kubectl get networkpolicies -A

# Check service endpoints
kubectl get endpoints -A

# Optimize network policies
kubectl apply -f security/network-policies.yaml
```

## 🛡️ Security Maintenance

### 1. Security Scanning

```bash
# Run security scan
task security:scan

# Validate security configurations
task security:validate

# Check external secrets
task secrets:status
```

### 2. Certificate Management

```bash
# Check certificate status
task certs:status

# Check certificate expiration
kubectl get certificates -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,READY:.status.conditions[0].status,EXPIRY:.status.notAfter

# Renew certificates if needed
kubectl delete certificate <cert-name> -n <namespace>
```

### 3. Access Review

```bash
# Review RBAC
kubectl get roles,clusterroles,rolebindings,clusterrolebindings -A

# Check service accounts
kubectl get serviceaccounts -A

# Review network policies
kubectl get networkpolicies -A
```

## 📊 Health Monitoring

### 1. Cluster Health

```bash
# Comprehensive health check
task health

# Check cluster components
kubectl get componentstatuses

# Check node status
kubectl get nodes -o wide
```

### 2. Application Health

```bash
# Check application status
task status

# Check pod status
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded

# Check service status
kubectl get svc -A
```

### 3. Security Health

```bash
# Security scan
task security:scan

# Check Pod Security Standards
kubectl get namespaces -o custom-columns=NAME:.metadata.name,PSS-ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce

# Check network policies
kubectl get networkpolicies -A
```

## 🔄 Cleanup Procedures

### 1. Resource Cleanup

```bash
# Clean up failed pods
kubectl delete pods --field-selector=status.phase=Failed --all-namespaces

# Clean up completed pods
kubectl delete pods --field-selector=status.phase=Succeeded --all-namespaces

# Clean up unused secrets
kubectl get secrets -A --field-selector=type=Opaque -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' | grep -v default
```

### 2. Log Cleanup

```bash
# Clean up old logs
kubectl logs <pod-name> -n <namespace> --since=24h

# Clean up Loki logs
kubectl exec -it <loki-pod> -n logging -- loki --config.file=/etc/loki/local-config.yaml
```

### 3. Backup Cleanup

```bash
# Clean up old backups
find backups/ -type f -mtime +30 -delete

# Clean up old remote backups
# (customize with your backup tooling)
```

## 📋 Maintenance Checklist

### Daily Maintenance

- [ ] **Health check completed**
- [ ] **Application status verified**
- [ ] **Security scan run**
- [ ] **Certificate status checked**
- [ ] **Logs reviewed**

### Weekly Maintenance

- [ ] **Resource usage reviewed**
- [ ] **Backup verification completed**
- [ ] **Security validation run**
- [ ] **Performance metrics reviewed**
- [ ] **Documentation updated**

### Monthly Maintenance

- [ ] **Certificate renewal verified**
- [ ] **Resource optimization completed**
- [ ] **Security updates applied**
- [ ] **Backup testing completed**
- [ ] **Disaster recovery tested**

### Quarterly Maintenance

- [ ] **Cluster upgrade planned**
- [ ] **Security audit completed**
- [ ] **Performance optimization reviewed**
- [ ] **Documentation updated**
- [ ] **Team training completed**

## 🚨 Emergency Procedures

### 1. Service Recovery

```bash
# Restart failed services
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# Scale down and up
kubectl scale deployment/<deployment-name> --replicas=0 -n <namespace>
kubectl scale deployment/<deployment-name> --replicas=1 -n <namespace>
```

### 2. Data Recovery

```bash
# Restore from Git backup
git checkout <backup-commit>
kubectl apply -f argocd/root-app.yaml
```

### 3. Cluster Recovery

```bash
# Restart cluster components
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout restart daemonset/kube-proxy -n kube-system

# Check cluster health
kubectl get componentstatuses
```

## 📚 Additional Resources

- [Incident Response Runbook](./INCIDENT_RESPONSE.md)
- [Deployment Runbook](./DEPLOYMENT.md)
- [Troubleshooting Runbook](./TROUBLESHOOTING.md)
- [Security Incident Runbook](./SECURITY_INCIDENT.md)
- [Main README](../README.md)
- [Security Enhancements](../security/SECURITY_ENHANCEMENTS.md)
