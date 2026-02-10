# Troubleshooting Runbook

## 🔍 Troubleshooting Methodology

### 1. Gather Information

- **Symptoms**: What is not working?
- **Timeline**: When did it start?
- **Scope**: What is affected?
- **Recent Changes**: What changed recently?

### 2. Quick Assessment

```bash
# Quick health check
task health

# Check cluster status
kubectl cluster-info

# Check node status
kubectl get nodes -o wide
```

### 3. Systematic Investigation

- **Cluster Level**: Nodes, networking, storage
- **Namespace Level**: Pods, services, configurations
- **Application Level**: Logs, metrics, dependencies

## 🚨 Common Issues & Solutions

### Issue 1: Pod Not Starting

#### Symptoms

- Pod stuck in `Pending` state
- Pod stuck in `ContainerCreating` state
- Pod in `CrashLoopBackOff` state

#### Investigation Steps

```bash
# 1. Check pod status
kubectl get pods -n <namespace>

# 2. Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# 3. Check pod logs
kubectl logs <pod-name> -n <namespace> --previous

# 4. Check resource quotas
kubectl get resourcequota -n <namespace>

# 5. Check node capacity
kubectl describe node <node-name>
```

#### Common Causes & Solutions

**Resource Constraints**

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n <namespace>

# Check resource quotas
kubectl describe resourcequota -n <namespace>

# Solution: Increase resource limits or quotas
kubectl patch resourcequota <quota-name> -n <namespace> -p '{"spec":{"hard":{"requests.cpu":"2","requests.memory":"4Gi"}}}'
```

**Image Pull Issues**

```bash
# Check image pull secrets
kubectl get secrets -n <namespace> | grep docker

# Check image pull events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Solution: Create image pull secret
kubectl create secret docker-registry <secret-name> \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n <namespace>
```

**Storage Issues**

```bash
# Check persistent volumes
kubectl get pv,pvc -n <namespace>

# Check storage class
kubectl get storageclass

# Solution: Check storage class availability
kubectl describe storageclass <storage-class-name>
```

### Issue: Flux GitRepository cannot clone (DNS)

#### Symptoms

- `gitrepository/mkloudlab` shows: `failed to checkout and determine revision: unable to clone ... dial tcp: lookup github.com on 10.96.0.10:53: server misbehaving`
- Kustomizations show: `Source artifact not found, retrying in 30s`

#### Cause

CoreDNS in the cluster is forwarding to the node’s `/etc/resolv.conf` (e.g. VirtualBox NAT), which often fails for pods.

#### Solution

Patch CoreDNS to use reliable upstream DNS, then restart Flux reconciliation:

```bash
task fix:dns
# Wait for CoreDNS rollout, then trigger Flux to retry
flux reconcile source git mkloudlab -n flux-system
task flux:status
```

Optional: use custom upstreams: `UPSTREAM_DNS="1.1.1.1 1.0.0.1" task fix:dns`

---

### Issue 2: Service Not Accessible

#### Symptoms

- Service returns 503 errors
- Service timeout
- DNS resolution failures

#### Investigation Steps

```bash
# 1. Check service status
kubectl get svc -n <namespace>

# 2. Check service endpoints
kubectl get endpoints -n <namespace>

# 3. Check pod status
kubectl get pods -n <namespace>

# 4. Test service connectivity
kubectl exec -it <pod-name> -n <namespace> -- curl <service-name>.<namespace>.svc.cluster.local

# 5. Check DNS resolution
kubectl exec -it <pod-name> -n <namespace> -- nslookup <service-name>.<namespace>.svc.cluster.local
```

#### Common Causes & Solutions

**No Endpoints**

```bash
# Check pod labels match service selector
kubectl get pods -n <namespace> --show-labels
kubectl get svc -n <namespace> -o yaml | grep selector

# Solution: Fix pod labels or service selector
kubectl label pod <pod-name> -n <namespace> app=<service-name>
```

**DNS Issues**

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Solution: Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

**Network Policy Issues**

```bash
# Check network policies
kubectl get networkpolicies -n <namespace>

# Test without network policies
kubectl delete networkpolicy <policy-name> -n <namespace>

# Solution: Update network policy to allow required traffic
```

### Issue 3: Certificate Problems

#### Symptoms

- TLS certificate errors
- Certificate not ready
- Certificate expiration warnings

#### Investigation Steps

```bash
# 1. Check certificate status
task certs:status

# 2. Describe certificate issues
task certs:describe

# 3. Check certificate requests
kubectl get certificaterequests -A

# 4. Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# 5. Check certificate issuer
kubectl get clusterissuers
```

#### Common Causes & Solutions

**DNS Issues**

```bash
# Check DNS resolution
task dns:check

# Test DNS from pod
kubectl exec -it <pod-name> -n <namespace> -- nslookup <domain-name>

# Solution: Fix DNS records
```

**Rate Limiting**

```bash
# Check Let's Encrypt rate limits
kubectl logs -n cert-manager -l app=cert-manager | grep rate

# Solution: Wait for rate limit reset or use staging issuer
```

**Certificate Issuer Issues**

```bash
# Check issuer status
kubectl describe clusterissuer letsencrypt-prod

# Solution: Fix issuer configuration
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: istio
EOF
```

### Issue 4: ArgoCD Sync Issues

#### Symptoms

- Applications out of sync
- ArgoCD UI showing errors
- GitOps not working

#### Investigation Steps

```bash
# 1. Check ArgoCD applications
kubectl get applications -n argocd

# 2. Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# 3. Check Git repository connectivity
kubectl describe application <app-name> -n argocd

# 4. Check ArgoCD server status
kubectl get pods -n argocd

# 5. Check ArgoCD configuration
kubectl get configmap argocd-cmd-params-cm -n argocd
```

#### Common Causes & Solutions

**Git Repository Issues**

```bash
# Check Git repository access
kubectl exec -it <argocd-server-pod> -n argocd -- git ls-remote <repo-url>

# Solution: Fix repository access or credentials
```

**Manifest Validation Issues**

```bash
# Check manifest validation
kubectl get applications <app-name> -n argocd -o yaml | grep -A 10 status

# Solution: Fix YAML syntax errors
task validate:manifests
```

**Permission Issues**

```bash
# Check ArgoCD service account permissions
kubectl auth can-i get pods --as=system:serviceaccount:argocd:argocd-application-controller

# Solution: Fix RBAC permissions
```

### Issue 5: Performance Issues

#### Symptoms

- Slow response times
- High resource usage
- Pod evictions

#### Investigation Steps

```bash
# 1. Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# 2. Check pod resource limits
kubectl describe pod <pod-name> -n <namespace>

# 3. Check node capacity
kubectl describe node <node-name>

# 4. Check resource quotas
kubectl get resourcequota -A

# 5. Check persistent volume usage
kubectl get pv,pvc -A
```

#### Common Causes & Solutions

**Resource Limits Too Low**

```bash
# Check current limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 resources

# Solution: Increase resource limits
kubectl patch deployment <deployment-name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"limits":{"cpu":"500m","memory":"512Mi"}}}]}}}}'
```

**Node Resource Exhaustion**

```bash
# Check node capacity
kubectl describe node <node-name>

# Solution: Add more nodes or optimize resource usage
```

**Storage Issues**

```bash
# Check storage usage
kubectl get pv,pvc -A

# Solution: Clean up unused volumes or increase storage
```

## 🔧 Diagnostic Commands

### Cluster Health

```bash
# Overall cluster health
task health

# Node status
kubectl get nodes -o wide

# Component status
kubectl get componentstatuses

# Cluster info
kubectl cluster-info
```

### Application Health

```bash
# All applications
task status

# Specific namespace
kubectl get all -n <namespace>

# Pod status
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
```

### Network Diagnostics

```bash
# DNS resolution
task dns:check

# Network policies
kubectl get networkpolicies -A

# Service endpoints
kubectl get endpoints -A

# Test connectivity
kubectl exec -it <pod-name> -n <namespace> -- curl <service-name>.<namespace>.svc.cluster.local
```

### Security Diagnostics

```bash
# Security scan
task security:scan

# Pod Security Standards
kubectl get namespaces -o custom-columns=NAME:.metadata.name,PSS-ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce

# RBAC status
kubectl get roles,clusterroles,rolebindings,clusterrolebindings -A
```

### Monitoring Diagnostics

```bash
# Prometheus status
kubectl get pods -n monitoring

# Grafana status
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Alertmanager status
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# Loki status
kubectl get pods -n logging
```

## 📊 Log Analysis

### Application Logs

```bash
# Current logs
kubectl logs <pod-name> -n <namespace>

# Previous logs (for crashed pods)
kubectl logs <pod-name> -n <namespace> --previous

# Follow logs
kubectl logs <pod-name> -n <namespace> -f

# Logs with timestamps
kubectl logs <pod-name> -n <namespace> --timestamps
```

### System Logs

```bash
# CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# CNI logs
kubectl logs -n kube-system -l app=flannel

# Storage logs
kubectl logs -n kube-system -l app=local-path-provisioner
```

### ArgoCD Logs

```bash
# ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# ArgoCD application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# ArgoCD repo server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

## 🛠 Recovery Procedures

### Pod Recovery

```bash
# Restart deployment
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# Scale down and up
kubectl scale deployment/<deployment-name> --replicas=0 -n <namespace>
kubectl scale deployment/<deployment-name> --replicas=1 -n <namespace>

# Delete and recreate pod
kubectl delete pod <pod-name> -n <namespace>
```

### Service Recovery

```bash
# Restart service
kubectl delete svc <service-name> -n <namespace>
kubectl apply -f <service-manifest>

# Check service endpoints
kubectl get endpoints -n <namespace>
```

### Application Recovery

```bash
# Force ArgoCD sync
task argocd:sync

# Restart ArgoCD server
kubectl rollout restart deployment/argocd-server -n argocd

# Clear ArgoCD cache
kubectl delete secret -n argocd -l app.kubernetes.io/name=argocd-server
```

### Cluster Recovery

```bash
# Restart cluster components
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout restart daemonset/kube-proxy -n kube-system

# Check cluster health
kubectl get componentstatuses
```

## 📋 Troubleshooting Checklist

### Initial Assessment

- [ ] **Symptoms documented**
- [ ] **Timeline established**
- [ ] **Scope determined**
- [ ] **Recent changes identified**

### Investigation

- [ ] **Cluster health checked**
- [ ] **Application status verified**
- [ ] **Logs analyzed**
- [ ] **Resource usage checked**
- [ ] **Network connectivity tested**

### Resolution

- [ ] **Root cause identified**
- [ ] **Solution implemented**
- [ ] **Service restored**
- [ ] **Monitoring confirmed**
- [ ] **Documentation updated**

### Follow-up

- [ ] **Incident documented**
- [ ] **Prevention measures identified**
- [ ] **Runbook updated**
- [ ] **Team notified**

## 📚 Additional Resources

- [Incident Response Runbook](./INCIDENT_RESPONSE.md)
- [Deployment Runbook](./DEPLOYMENT.md)
- [Maintenance Runbook](./MAINTENANCE.md)
- [Security Incident Runbook](./SECURITY_INCIDENT.md)
- [Main README](../README.md)
- [Security Enhancements](../security/SECURITY_ENHANCEMENTS.md)
