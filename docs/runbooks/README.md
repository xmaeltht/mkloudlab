# Runbooks Index

## 📚 Overview

This directory contains comprehensive runbooks for operating the Mkloudlab Kubernetes GitOps environment. Each runbook provides detailed procedures for specific operational scenarios.

## 📖 Available Runbooks

### 🚨 [Incident Response Runbook](./INCIDENT_RESPONSE.md)

**Purpose**: Handle production incidents and outages
**When to use**: Service down, performance issues, system failures
**Key features**:

- Emergency contacts and escalation procedures
- Severity level definitions (P1-P4)
- Common incident scenarios with step-by-step resolution
- Post-incident procedures and communication templates
- Emergency command reference

### 🚀 [Deployment Runbook](./DEPLOYMENT.md)

**Purpose**: Deploy and configure the entire stack
**When to use**: Initial deployment, major updates, environment setup
**Key features**:

- Prerequisites checklist
- Phase-by-phase deployment process
- Verification procedures
- Common deployment issues and solutions
- Rollback procedures

### 🔧 [Troubleshooting Runbook](./TROUBLESHOOTING.md)

**Purpose**: Diagnose and resolve operational issues
**When to use**: Performance problems, configuration issues, service failures
**Key features**:

- Systematic troubleshooting methodology
- Common issues and solutions
- Diagnostic commands and tools
- Log analysis procedures
- Recovery procedures

### 🔄 [Maintenance Runbook](./MAINTENANCE.md)

**Purpose**: Routine maintenance and optimization
**When to use**: Daily operations, updates, performance tuning
**Key features**:

- Maintenance schedules (daily, weekly, monthly, quarterly)
- Update procedures for applications and security
- Backup and recovery procedures
- Performance optimization
- Health monitoring

### 🛡️ [Security Incident Runbook](./SECURITY_INCIDENT.md)

**Purpose**: Handle security incidents and breaches
**When to use**: Security alerts, unauthorized access, policy violations
**Key features**:

- Security incident response procedures
- Common security scenarios
- Forensic analysis and evidence collection
- Recovery and restoration procedures
- Post-incident actions

## 🎯 Quick Reference

### Emergency Situations

| Situation                | Primary Runbook                             | Secondary Runbook                           |
| ------------------------ | ------------------------------------------- | ------------------------------------------- |
| **Service Down**         | [Incident Response](./INCIDENT_RESPONSE.md) | [Troubleshooting](./TROUBLESHOOTING.md)     |
| **Security Breach**      | [Security Incident](./SECURITY_INCIDENT.md) | [Incident Response](./INCIDENT_RESPONSE.md) |
| **Performance Issues**   | [Troubleshooting](./TROUBLESHOOTING.md)     | [Maintenance](./MAINTENANCE.md)             |
| **Deployment Failure**   | [Deployment](./DEPLOYMENT.md)               | [Troubleshooting](./TROUBLESHOOTING.md)     |
| **Configuration Issues** | [Troubleshooting](./TROUBLESHOOTING.md)     | [Maintenance](./MAINTENANCE.md)             |

### Routine Operations

| Task                    | Primary Runbook                 | Frequency |
| ----------------------- | ------------------------------- | --------- |
| **Health Checks**       | [Maintenance](./MAINTENANCE.md) | Daily     |
| **Security Scans**      | [Maintenance](./MAINTENANCE.md) | Daily     |
| **Backup Verification** | [Maintenance](./MAINTENANCE.md) | Weekly    |
| **Performance Review**  | [Maintenance](./MAINTENANCE.md) | Weekly    |
| **Security Updates**    | [Maintenance](./MAINTENANCE.md) | Monthly   |

## 🔍 How to Use These Runbooks

### 1. Identify the Situation

- **Emergency**: Use Incident Response or Security Incident runbooks
- **Routine**: Use Maintenance runbook
- **Problem Solving**: Use Troubleshooting runbook
- **New Deployment**: Use Deployment runbook

### 2. Follow the Process

- **Read the overview** and prerequisites
- **Follow step-by-step procedures**
- **Use provided commands** and checklists
- **Document actions taken**
- **Complete follow-up tasks**

### 3. Escalate When Needed

- **P1/P2 incidents**: Immediate escalation
- **Complex issues**: Escalate to senior team members
- **Security incidents**: Follow security escalation procedures
- **Unknown scenarios**: Consult with team leads

## 🛠️ Common Commands Reference

### Quick Health Check

```bash
# Comprehensive health check
task health

# Application status
task status

# Security scan
task security:scan
```

### Emergency Commands

```bash
# Restart all deployments in namespace
kubectl rollout restart deployment -n <namespace>

# Scale down all deployments
kubectl scale deployment --replicas=0 -n <namespace>

# Force ArgoCD sync
task argocd:sync

# Get ArgoCD admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
```

### Diagnostic Commands

```bash
# Check pod status
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check network policies
kubectl get networkpolicies -A

# Check certificates
task certs:status
```

## 📞 Emergency Contacts

### Primary Contacts

- **On-Call Engineer**: [Your Name] - [Phone/Email]
- **Team Lead**: [Name] - [Phone/Email]
- **DevOps Manager**: [Name] - [Phone/Email]

### Security Contacts

- **Security Team Lead**: [Name] - [Phone/Email]
- **Legal/Compliance**: [Name] - [Phone/Email]
- **External Security**: [Name] - [Phone/Email]

### Escalation Matrix

| Severity          | Response Time | Escalation                          |
| ----------------- | ------------- | ----------------------------------- |
| **P1 - Critical** | 15 minutes    | Immediate escalation                |
| **P2 - High**     | 1 hour        | Escalate if not resolved in 2 hours |
| **P3 - Medium**   | 4 hours       | Escalate if not resolved in 8 hours |
| **P4 - Low**      | 24 hours      | Next business day                   |

## 📋 Runbook Maintenance

### Keeping Runbooks Current

- [ ] **Review runbooks monthly**
- [ ] **Update procedures** when processes change
- [ ] **Add new scenarios** as they occur
- [ ] **Remove outdated information**
- [ ] **Test procedures** during maintenance windows

### Feedback and Improvements

- [ ] **Collect feedback** from team members
- [ ] **Document lessons learned** from incidents
- [ ] **Update runbooks** based on experience
- [ ] **Share improvements** with the team
- [ ] **Train team members** on updated procedures

## 🔗 Related Documentation

- [Main README](../README.md) - Project overview and setup
- [Taskfile Quick Start](../reference/TASKFILE_QUICKSTART.md) - Automation guide
- [Security Enhancements](../security/SECURITY_ENHANCEMENTS.md) - Security features
- [Deployment Guide](../README.md#automated-deployment-with-argocd) - Deployment instructions

## 📚 Additional Resources

### External Documentation

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

### Training Resources

- [Kubernetes Training](https://kubernetes.io/training/)
- [CNCF Training](https://www.cncf.io/certification/training/)
- [Security Training](https://kubernetes.io/docs/concepts/security/)

---

**Last Updated**: [Current Date]
**Version**: 1.0
**Maintained by**: DevOps Team
