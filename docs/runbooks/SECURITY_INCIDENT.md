# Security Incident Runbook

## 🚨 Security Incident Response

### Emergency Contacts

- **Security Team Lead**: [Name] - [Phone/Email]
- **DevOps Manager**: [Name] - [Phone/Email]
- **Legal/Compliance**: [Name] - [Phone/Email]
- **External Security**: [Name] - [Phone/Email]

### Severity Levels

| Level        | Description                           | Response Time | Escalation |
| ------------ | ------------------------------------- | ------------- | ---------- |
| **Critical** | Active breach, data exfiltration      | 15 minutes    | Immediate  |
| **High**     | Potential breach, suspicious activity | 1 hour        | 2 hours    |
| **Medium**   | Security policy violation             | 4 hours       | 8 hours    |
| **Low**      | Security warning, compliance issue    | 24 hours      | Next day   |

## 🔍 Initial Assessment

### 1. Immediate Actions

```bash
# Isolate affected systems
kubectl scale deployment <affected-deployment> --replicas=0 -n <namespace>

# Check current security status
task security:scan

# Check network policies
kubectl get networkpolicies -A

# Check RBAC status
kubectl get roles,clusterroles,rolebindings,clusterrolebindings -A
```

### 2. Information Gathering

```bash
# Check pod security standards
kubectl get namespaces -o custom-columns=NAME:.metadata.name,PSS-ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce

# Check external secrets
task secrets:status

# Check certificate status
task certs:status

# Check for suspicious pods
kubectl get pods --all-namespaces -o wide
```

### 3. Log Collection

```bash
# Collect security logs
kubectl logs -n kyverno -l app.kubernetes.io/part-of=kyverno --since=24h > security-logs.txt

# Collect audit logs
kubectl get events --all-namespaces --sort-by='.lastTimestamp' > audit-events.txt

# Collect network logs
kubectl logs -n kube-system -l k8s-app=kube-dns --since=24h > dns-logs.txt
```

## 🚨 Common Security Scenarios

### Scenario 1: Unauthorized Access

#### Symptoms

- Unknown pods in cluster
- Unusual network traffic
- Unauthorized service accounts
- Suspicious RBAC changes

#### Immediate Response

```bash
# 1. Identify suspicious resources
kubectl get pods --all-namespaces -o wide | grep -v "Running\|Completed"

# 2. Check service accounts
kubectl get serviceaccounts -A

# 3. Check RBAC changes
kubectl get roles,clusterroles,rolebindings,clusterrolebindings -A

# 4. Check network policies
kubectl get networkpolicies -A
```

#### Containment Actions

```bash
# Delete suspicious pods
kubectl delete pod <suspicious-pod> -n <namespace> --force --grace-period=0

# Revoke suspicious service accounts
kubectl delete serviceaccount <suspicious-sa> -n <namespace>

# Remove suspicious RBAC
kubectl delete rolebinding <suspicious-binding> -n <namespace>

# Apply stricter network policies
kubectl apply -f security/network-policies.yaml
```

#### Investigation Steps

```bash
# Check pod logs
kubectl logs <suspicious-pod> -n <namespace> --previous

# Check pod configuration
kubectl describe pod <suspicious-pod> -n <namespace>

# Check for privilege escalation
kubectl get pod <suspicious-pod> -n <namespace> -o yaml | grep -A 10 securityContext

# Check for host access
kubectl get pod <suspicious-pod> -n <namespace> -o yaml | grep -A 5 hostPath
```

### Scenario 2: Malicious Container Images

#### Symptoms

- Unknown container images
- Image pull errors
- Container runtime alerts
- Unusual container behavior

#### Immediate Response

```bash
# 1. Check running containers
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# 2. Check image pull secrets
kubectl get secrets -A | grep docker

# 3. Check container security context
kubectl get pods --all-namespaces -o yaml | grep -A 10 securityContext
```

#### Containment Actions

```bash
# Stop suspicious deployments
kubectl scale deployment <suspicious-deployment> --replicas=0 -n <namespace>

# Delete suspicious pods
kubectl delete pod <suspicious-pod> -n <namespace> --force --grace-period=0

# Block malicious images
kubectl create configmap blocked-images -n kyverno --from-literal=images="malicious-image:latest"

# Apply image validation policy
kubectl apply -f kyverno/policies/clusterpolicy.yaml
```

#### Investigation Steps

```bash
# Check container logs
kubectl logs <suspicious-pod> -n <namespace> --previous

# Check container processes
kubectl exec -it <suspicious-pod> -n <namespace> -- ps aux

# Check container filesystem
kubectl exec -it <suspicious-pod> -n <namespace> -- ls -la /

# Check network connections
kubectl exec -it <suspicious-pod> -n <namespace> -- netstat -tulpn
```

### Scenario 3: Network Intrusion

#### Symptoms

- Unusual network traffic
- DNS resolution issues
- Network policy violations
- Suspicious ingress/egress

#### Immediate Response

```bash
# 1. Check network policies
kubectl get networkpolicies -A

# 2. Check service endpoints
kubectl get endpoints -A

# 3. Check ingress controllers
kubectl get ingress -A

# 4. Check Gateway API resources
kubectl get gateways,httproutes -A
```

#### Containment Actions

```bash
# Apply stricter network policies
kubectl apply -f security/network-policies.yaml

# Block suspicious IPs
kubectl create configmap blocked-ips -n kyverno --from-literal=ips="suspicious-ip"

# Disable ingress temporarily
kubectl scale deployment istio-ingressgateway --replicas=0 -n istio-system

# Apply default deny policies
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

#### Investigation Steps

```bash
# Check network traffic
kubectl exec -it <pod> -n <namespace> -- netstat -tulpn

# Check DNS queries
kubectl exec -it <pod> -n <namespace> -- nslookup <suspicious-domain>

# Check network connections
kubectl exec -it <pod> -n <namespace> -- ss -tulpn

# Check for network scanning
kubectl logs -n kube-system -l k8s-app=kube-dns | grep <suspicious-domain>
```

### Scenario 4: Privilege Escalation

#### Symptoms

- Unusual RBAC changes
- Privileged containers
- Host namespace access
- Security context violations

#### Immediate Response

```bash
# 1. Check RBAC changes
kubectl get roles,clusterroles,rolebindings,clusterrolebindings -A

# 2. Check privileged containers
kubectl get pods --all-namespaces -o yaml | grep -A 5 privileged

# 3. Check host namespace access
kubectl get pods --all-namespaces -o yaml | grep -A 5 hostNetwork

# 4. Check security contexts
kubectl get pods --all-namespaces -o yaml | grep -A 10 securityContext
```

#### Containment Actions

```bash
# Revoke suspicious RBAC
kubectl delete rolebinding <suspicious-binding> -n <namespace>

# Remove privileged access
kubectl patch deployment <deployment> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","securityContext":{"privileged":false}}]}}}}'

# Apply Pod Security Standards
kubectl label namespace <namespace> pod-security.kubernetes.io/enforce=restricted

# Apply Kyverno policies
kubectl apply -f kyverno/policies/clusterpolicy.yaml
```

#### Investigation Steps

```bash
# Check RBAC audit logs
kubectl get events --all-namespaces | grep -i rbac

# Check privilege escalation attempts
kubectl logs -n kyverno -l app.kubernetes.io/part-of=kyverno | grep -i privilege

# Check security context violations
kubectl get pods --all-namespaces -o yaml | grep -A 10 securityContext
```

## 🔧 Forensic Analysis

### 1. Evidence Collection

```bash
# Create evidence directory
mkdir -p evidence/$(date +%Y%m%d-%H%M%S)

# Collect cluster state
kubectl get all -A -o yaml > evidence/$(date +%Y%m%d-%H%M%S)/cluster-state.yaml

# Collect security configurations
kubectl get networkpolicies,rbac -A -o yaml > evidence/$(date +%Y%m%d-%H%M%S)/security-config.yaml

# Collect logs
kubectl logs --all-namespaces --since=24h > evidence/$(date +%Y%m%d-%H%M%S)/all-logs.txt
```

### 2. Timeline Analysis

```bash
# Check events timeline
kubectl get events --all-namespaces --sort-by='.lastTimestamp' > evidence/$(date +%Y%m%d-%H%M%S)/events-timeline.txt

# Check pod creation timeline
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,CREATED:.metadata.creationTimestamp > evidence/$(date +%Y%m%d-%H%M%S)/pod-timeline.txt
```

### 3. Network Analysis

```bash
# Check network policies
kubectl get networkpolicies -A -o yaml > evidence/$(date +%Y%m%d-%H%M%S)/network-policies.yaml

# Check service endpoints
kubectl get endpoints -A -o yaml > evidence/$(date +%Y%m%d-%H%M%S)/endpoints.yaml

# Check ingress configurations
kubectl get ingress -A -o yaml > evidence/$(date +%Y%m%d-%H%M%S)/ingress.yaml
```

## 🛡️ Recovery Procedures

### 1. Immediate Recovery

```bash
# Isolate affected systems
kubectl scale deployment <affected-deployment> --replicas=0 -n <namespace>

# Apply emergency network policies
kubectl apply -f security/network-policies.yaml

# Revoke suspicious access
kubectl delete rolebinding <suspicious-binding> -n <namespace>

# Restart security services
kubectl rollout restart deployment/kyverno-admission-controller -n kyverno
kubectl rollout restart daemonset/alloy-agent -n observability
kubectl rollout restart deployment/tempo-query-frontend -n observability
kubectl rollout restart statefulset/tempo-ingester -n observability
```

### 2. System Restoration

```bash
# Restore from clean backup
# (replace with your preferred backup tooling)

# Verify restoration
kubectl get pods --all-namespaces

# Apply security policies
kubectl apply -f security/

# Verify security status
task security:scan
```

### 3. Access Restoration

```bash
# Restore legitimate access
kubectl apply -f security/rbac-policies.yaml

# Verify RBAC
kubectl get roles,clusterroles,rolebindings,clusterrolebindings -A

# Test access
kubectl auth can-i get pods --as=system:serviceaccount:<namespace>:<service-account>
```

## 📊 Post-Incident Actions

### 1. Documentation

- [ ] **Incident timeline documented**
- [ ] **Evidence collected and preserved**
- [ ] **Root cause analysis completed**
- [ ] **Impact assessment documented**
- [ ] **Recovery steps documented**

### 2. Communication

- [ ] **Stakeholders notified**
- [ ] **Legal/Compliance informed**
- [ ] **External parties notified** (if required)
- [ ] **Public disclosure** (if required)

### 3. Follow-up Actions

- [ ] **Security policies updated**
- [ ] **Monitoring improved**
- [ ] **Access controls strengthened**
- [ ] **Training conducted**
- [ ] **Runbooks updated**

## 🔍 Security Monitoring

### 1. Continuous Monitoring

```bash
# Security scan
task security:scan

# Network policy monitoring
kubectl get networkpolicies -A

# RBAC monitoring
kubectl get roles,clusterroles,rolebindings,clusterrolebindings -A

# Alloy collector health
kubectl get pods -n observability
# Tempo health
kubectl get pods -n observability -l app.kubernetes.io/name=tempo

# Pod Security Standards monitoring
kubectl get namespaces -o custom-columns=NAME:.metadata.name,PSS-ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce
```

### 2. Alert Configuration

```bash
# Check Alertmanager configuration
kubectl get configmap alertmanager -n monitoring -o yaml

# Check Prometheus rules
kubectl get prometheusrules -n monitoring

# Check Grafana dashboards
kubectl get configmap grafana-dashboard -n monitoring -o yaml
```

### 3. Log Analysis

```bash
# Security logs
kubectl logs -n kyverno -l app.kubernetes.io/part-of=kyverno

# Audit logs
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Network logs
kubectl logs -n kube-system -l k8s-app=kube-dns
```

## 📋 Security Incident Checklist

### Initial Response

- [ ] **Incident severity determined**
- [ ] **Affected systems identified**
- [ ] **Containment actions taken**
- [ ] **Evidence collection started**
- [ ] **Stakeholders notified**

### Investigation

- [ ] **Root cause identified**
- [ ] **Impact assessed**
- [ ] **Timeline established**
- [ ] **Evidence preserved**
- [ ] **Forensic analysis completed**

### Recovery

- [ ] **Affected systems restored**
- [ ] **Security policies applied**
- [ ] **Access controls verified**
- [ ] **Monitoring confirmed**
- [ ] **System functionality tested**

### Post-Incident

- [ ] **Incident documented**
- [ ] **Lessons learned captured**
- [ ] **Policies updated**
- [ ] **Training conducted**
- [ ] **Runbooks updated**

## 📚 Additional Resources

- [Incident Response Runbook](./INCIDENT_RESPONSE.md)
- [Deployment Runbook](./DEPLOYMENT.md)
- [Troubleshooting Runbook](./TROUBLESHOOTING.md)
- [Maintenance Runbook](./MAINTENANCE.md)
- [Security Enhancements](../security/SECURITY_ENHANCEMENTS.md)
- [Main README](../README.md)
