# GitOps Workflow - Professional Deployment Guide

## Overview

This repository follows a **pure GitOps approach** where all deployments are managed through:

1. **Git as the source of truth** - All manifests committed to Git
2. **ArgoCD as the GitOps engine** - Pulls from Git and applies to cluster
3. **Taskfile for automation** - All operations managed through `task` commands
4. **No manual kubectl** - Everything reproducible through Taskfile

## Prerequisites

1. **Git repository** - Code must be committed and pushed to GitHub
2. **ArgoCD installed** - Managed via `task install:argocd`
3. **Cluster access** - `kubectl` configured and cluster accessible

## Standard Deployment Workflow

### 1. Initial Setup (One-time)

```bash
# Install prerequisites (Gateway API, cert-manager, Istio, etc.)
task install:prerequisites

# Configure Cloudflare token for certificates
export CLOUDFLARE_API_TOKEN="your_token_here"

# Full installation (prerequisites + ArgoCD + apps + certificates)
task install
```

The `task install` command will:

- Install all prerequisites
- Install and configure ArgoCD
- Configure ArgoCD repository access
- Ensure code is committed/pushed to Git
- Register all ArgoCD applications
- Trigger sync for all applications
- Configure certificates

### 2. Making Changes (Development Workflow)

```bash
# 1. Make your changes to manifests
vim platform/observability/alloy/config/alloy.river

# 2. Validate changes
task validate:manifests

# 3. Commit and push to Git (required for ArgoCD)
task gitops:push

# 4. ArgoCD will automatically sync (if auto-sync enabled)
# OR manually trigger sync:
task argocd:sync-all

# 5. Monitor deployment
task status
task health
```

### 3. Certificate Management

```bash
# Configure Cloudflare token
export CLOUDFLARE_API_TOKEN="your_token"
task certificates:configure-token

# Apply all certificates
task certificates:apply-all

# Check certificate status
task certificates:status

# Troubleshoot certificate issues
task certificates:describe
```

## Taskfile Commands Reference

### Installation & Setup

- `task install` - Full stack installation (prerequisites + ArgoCD + apps)
- `task install:prerequisites` - Install infrastructure prerequisites
- `task install:argocd` - Install and configure ArgoCD
- `task install:apps` - Register all ArgoCD applications
- `task install:certificates` - Configure and apply TLS certificates

### GitOps Operations

- `task gitops:ensure-committed` - Verify code is committed (required for ArgoCD)
- `task gitops:push` - Commit and push all changes to Git
- `task argocd:configure-repo` - Configure ArgoCD repository credentials
- `task argocd:sync-all` - Force sync all ArgoCD applications

### Certificate Management

- `task certificates:configure-token` - Set up Cloudflare API token
- `task certificates:apply-all` - Apply all certificate manifests
- `task certificates:status` - Check certificate status
- `task certificates:describe` - Troubleshoot certificate issues

### Monitoring & Status

- `task status` - Show deployment status
- `task health` - Comprehensive health check
- `task argocd:ui` - Show ArgoCD UI access info

## Important Notes

### Git as Source of Truth

**ArgoCD requires code to be in Git**. The workflow is:

1. Make changes locally
2. Commit to Git
3. Push to remote repository
4. ArgoCD pulls from Git and applies changes

**Never apply manifests directly with kubectl** - Always use Git + ArgoCD.

### Certificate Persistence

Certificates are configured with:

- **Auto-renewal**: 30 days before expiration
- **Protection**: Kyverno policy prevents accidental deletion
- **Manual deletion**: Requires annotation `cert-manager.io/allow-deletion=true`

### Reproducibility

All operations are reproducible through Taskfile:

- Same commands work on any environment
- No manual steps required
- Full audit trail through Git commits
- ArgoCD provides deployment history

## Troubleshooting

### ArgoCD Apps Show "Unknown" Status

This usually means:

1. Code not pushed to Git - Run `task gitops:push`
2. Repository not configured - Run `task argocd:configure-repo`
3. Path doesn't exist in repo - Verify paths in ArgoCD app manifests

### Certificates Not Issuing

1. Check Cloudflare token: `task certificates:configure-token`
2. Verify ClusterIssuer: `kubectl get clusterissuers`
3. Check certificate status: `task certificates:status`
4. Review certificate requests: `kubectl get certificaterequests -A`

### Applications Not Deploying

1. Check ArgoCD sync status: `kubectl get applications -n argocd`
2. Review application logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`
3. Force sync: `task argocd:sync-all`
4. Check health: `task health`

## Best Practices

1. **Always use Taskfile** - Never run kubectl directly for deployments
2. **Commit before deploying** - ArgoCD needs code in Git
3. **Validate before pushing** - Run `task validate:manifests` first
4. **Monitor deployments** - Use `task status` and `task health`
5. **Use GitOps workflow** - Changes → Commit → Push → ArgoCD syncs
