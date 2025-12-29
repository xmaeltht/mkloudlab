# Deployment Runbook

## 🚀 Deployment Overview

This runbook covers the complete deployment process for the Mkloudlab Kubernetes GitOps environment, from initial setup to production deployment.

## 📋 Prerequisites Checklist

### Infrastructure Requirements

- [ ] **Kubernetes cluster** (v1.24+)
- [ ] **kubectl** configured and tested
- [ ] **Domain name** configured (maelkloud.com)
- [ ] **DNS records** pointing to cluster
- [ ] **Storage class** available (local-path)
- [ ] **Load balancer** configured (MetalLB or cloud LB)

### Access Requirements

- [ ] **Cluster admin access**
- [ ] **Git repository access**
- [ ] **Domain management access**
- [ ] **Certificate authority access** (Let's Encrypt)

### Tools Required

- [ ] **Task** installed (`brew install go-task/tap/go-task`)
- [ ] **kubectl** configured
- [ ] **argocd CLI** (optional)
- [ ] **terraform** (for Keycloak setup)

## 🔧 Deployment Steps

### Phase 1: Initial Cluster Setup

#### 1.1 Validate Cluster

```bash
# Check cluster connectivity
task validate:cluster

# Verify cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Verify storage class
kubectl get storageclass
```

#### 1.2 Install ArgoCD

```bash
# Install ArgoCD
task install:argocd

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment -n argocd -l app.kubernetes.io/name=argocd-server

# Verify ArgoCD installation
kubectl get pods -n argocd
```

#### 1.3 Deploy Applications

```bash
# Deploy all ArgoCD applications independently
task install:apps

# Monitor deployment progress
watch kubectl get applications -n argocd
```

### Phase 2: Core Services Deployment

#### 2.1 Monitor Core Services

```bash
# Check application status
task status

# Monitor specific applications
kubectl get applications -n argocd -o wide

# Check pod status
kubectl get pods --all-namespaces
```

#### 2.2 Verify Core Services

```bash
# Check Istio (Service Mesh & Gateway)
kubectl get pods -n istio-system
kubectl get svc -n istio-system
kubectl get gateway --all-namespaces

# Check Cert-Manager
kubectl get pods -n cert-manager
kubectl get clusterissuers

# Check Kyverno
kubectl get pods -n kyverno
kubectl get clusterpolicies
```

### Phase 3: Application Services Deployment

#### 3.1 Monitor Application Services

```bash
# Check application services
kubectl get pods -n keycloak
kubectl get pods -n monitoring
kubectl get pods -n observability

# Verify Tempo status
kubectl get pods -n observability -l app.kubernetes.io/name=tempo
```

#### 3.2 Verify Service Connectivity

```bash
# Check service endpoints
kubectl get endpoints -A

# Test DNS resolution
task dns:check

# Check Gateway API resources
task gateway:status
```

### Phase 4: Security Configuration

#### 4.1 Deploy Security Configurations

```bash
# Deploy security configurations
kubectl apply -f argocd/apps/security-config-app.yaml

# Verify security deployment
task security:validate

# Check Pod Security Standards
kubectl get namespaces -o custom-columns=NAME:.metadata.name,PSS-ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce
```

#### 4.2 Verify Security Policies

```bash
# Check network policies
kubectl get networkpolicies -A

# Check RBAC policies
kubectl get roles,clusterroles,rolebindings,clusterrolebindings -A

# Run security scan
task security:scan
```

### Phase 5: Monitoring & Logging

#### 5.1 Deploy Monitoring Stack

```bash
# Check Prometheus deployment
kubectl get pods -n monitoring

# Check Grafana deployment
kubectl get pods -n monitoring

# Verify Alertmanager
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager
```

#### 5.2 Deploy Logging Stack

```bash
# Check Loki deployment
kubectl get pods -n logging

# Check Promtail deployment
kubectl get pods -n logging

# Verify log collection
kubectl logs -n logging -l app.kubernetes.io/name=promtail --tail=10
```

### Phase 6: Certificate Management

#### 6.1 Verify Certificate Status

```bash
# Check certificate status
task certs:status

# Describe certificate issues
task certs:describe

# Check certificate requests
kubectl get certificaterequests -A
```

#### 6.2 Troubleshoot Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate issuer
kubectl get clusterissuers

# Force certificate renewal if needed
kubectl delete certificate <cert-name> -n <namespace>
```

### Phase 7: Post-Deployment Configuration

#### 7.1 Configure Keycloak

```bash
# Run Keycloak Terraform setup
task terraform:keycloak:setup

# Create OAuth secrets
task terraform:secrets:create

# Verify Keycloak configuration
kubectl get pods -n keycloak
```

#### 7.2 Configure External Secrets

```bash
# Check external secrets status
task secrets:status

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

## 🔍 Deployment Verification

### Health Checks

```bash
# Comprehensive health check
task health

# Check all services
task status

# Verify security
task security:validate

# Check monitoring
kubectl get pods -n monitoring
```

### Service Access Verification

```bash
# Check service URLs
task access

# Test DNS resolution
task dns:check

# Verify certificates
task certs:status

# Check Gateway API
task gateway:status
```

### Performance Verification

```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check resource quotas
kubectl get resourcequota -A

# Check persistent volumes
kubectl get pv,pvc -A
```

## 🚨 Common Deployment Issues

### Issue 1: ArgoCD Applications Not Syncing

#### Symptoms

- Applications stuck in "OutOfSync" status
- ArgoCD UI showing sync errors

#### Resolution

```bash
# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Force sync all applications
task argocd:sync

# Check Git repository connectivity
kubectl describe application <app-name> -n argocd

# Restart ArgoCD server if needed
kubectl rollout restart deployment/argocd-server -n argocd
```

### Issue 2: Certificate Issues

#### Symptoms

- Certificates not ready
- Certificate request failures
- TLS errors

#### Resolution

```bash
# Check cert-manager status
kubectl get pods -n cert-manager

# Check certificate issuer
kubectl get clusterissuers

# Check certificate requests
kubectl get certificaterequests -A

# Check DNS resolution
task dns:check

# Force certificate renewal
kubectl delete certificate <cert-name> -n <namespace>
```

### Issue 3: Pod Startup Issues

#### Symptoms

- Pods stuck in Pending state
- CrashLoopBackOff errors
- Image pull errors

#### Resolution

```bash
# Check pod status
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# Check pod logs
kubectl logs <pod-name> -n <namespace> --previous

# Check resource quotas
kubectl get resourcequota -A

# Check node capacity
kubectl describe node <node-name>

# Check image pull secrets
kubectl get secrets -A | grep docker
```

### Issue 4: Network Connectivity Issues

#### Symptoms

- Services unreachable
- DNS resolution failures
- Network policy violations

#### Resolution

```bash
# Check network policies
kubectl get networkpolicies -A

# Test DNS resolution
kubectl exec -it <pod-name> -n <namespace> -- nslookup kubernetes.default.svc.cluster.local

# Check service endpoints
kubectl get endpoints -A

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

## 📊 Deployment Monitoring

### Key Metrics to Monitor

- **Application Health**: Pod status, service endpoints
- **Resource Usage**: CPU, memory, storage
- **Network**: DNS resolution, service connectivity
- **Security**: Pod Security Standards, network policies
- **Certificates**: Certificate status, expiration dates

### Monitoring Commands

```bash
# Continuous monitoring
watch kubectl get pods --all-namespaces

# Resource monitoring
watch kubectl top nodes

# Application monitoring
watch kubectl get applications -n argocd

# Security monitoring
watch kubectl get networkpolicies -A
```

## 🔄 Rollback Procedures

### Application Rollback

```bash
# Rollback specific application
kubectl rollout undo deployment/<deployment-name> -n <namespace>

# Rollback ArgoCD application
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{"revision":"<previous-revision>"}}}'

# Rollback to previous Git commit
git checkout <previous-commit>
kubectl apply -f argocd/root-app.yaml
```

### Complete Rollback

```bash
# Uninstall entire stack
task uninstall

# Clean up resources
task clean

# Restore from backup
task backup
```

## 📋 Deployment Checklist

### Pre-Deployment

- [ ] **Cluster validated**
- [ ] **DNS configured**
- [ ] **Storage class available**
- [ ] **Load balancer configured**
- [ ] **Access credentials ready**

### During Deployment

- [ ] **ArgoCD installed**
- [ ] **Root application deployed**
- [ ] **Core services running**
- [ ] **Applications deployed**
- [ ] **Security configured**
- [ ] **Monitoring active**

### Post-Deployment

- [ ] **Health checks passed**
- [ ] **Services accessible**
- [ ] **Certificates valid**
- [ ] **Security policies active**
- [ ] **Monitoring configured**
- [ ] **Documentation updated**

## 🎯 Success Criteria

### Technical Success

- ✅ All pods running successfully
- ✅ All services accessible via HTTPS
- ✅ Certificates valid and auto-renewing
- ✅ Security policies enforced
- ✅ Monitoring and alerting active

### Operational Success

- ✅ GitOps workflow functional
- ✅ Automated deployments working
- ✅ Backup and recovery tested
- ✅ Documentation complete
- ✅ Team trained on operations

## 📚 Additional Resources

- [Main README](../README.md)
- [Taskfile Quick Start](../reference/TASKFILE_QUICKSTART.md)
- [Security Enhancements](../security/SECURITY_ENHANCEMENTS.md)
- [Incident Response Runbook](./INCIDENT_RESPONSE.md)
- [Troubleshooting Runbook](./TROUBLESHOOTING.md)
