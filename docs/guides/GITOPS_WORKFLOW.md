# GitOps Workflow - Professional Deployment Guide

## Overview

This repository follows a **pure GitOps approach** where all deployments are managed through:

1. **Git as the source of truth** - All manifests committed to Git
2. **Flux CD as the GitOps engine** - Pulls from Git and applies to cluster
3. **Taskfile for automation** - All operations managed through `task` commands
4. **No manual kubectl** - Everything reproducible through Taskfile

## Prerequisites

1. **Git repository** - Code must be committed and pushed to GitHub
2. **Flux CD installed** - Managed via `task install:flux`
3. **Cluster access** - `kubectl` configured and cluster accessible

## Standard Deployment Workflow

### 1. Initial Setup (One-time)

```bash
# Install prerequisites (Gateway API, cert-manager, Istio, etc.)
task install:prerequisites

# Configure Cloudflare token for certificates
export CLOUDFLARE_API_TOKEN="your_token_here"

# Full installation (prerequisites + Flux + apps + certificates)
task install
```

The `task install` command will:

- Install all prerequisites
- Install and configure Flux CD
- Configure Flux GitRepository
- Ensure code is committed/pushed to Git
- Register all Flux applications
- Configure certificates

### 2. Making Changes (Development Workflow)

```bash
# 1. Make your changes to manifests
vim platform/observability/alloy/config/alloy.river

# 2. Validate changes
task validate:manifests

# 3. Commit and push to Git (required for Flux)
task gitops:push

# 4. Flux will automatically reconcile (if configured)
# OR manually trigger reconciliation:
task flux:sync-all

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

- `task install` - Full stack installation (prerequisites + Flux + apps)
- `task install:prerequisites` - Install infrastructure prerequisites
- `task install:flux` - Install and configure Flux CD
- `task install:apps` - Register all Flux applications
- `task install:certificates` - Configure and apply TLS certificates

### GitOps Operations

- `task gitops:ensure-committed` - Verify code is committed (required for Flux)
- `task gitops:push` - Commit and push all changes to Git
- `task flux:configure-repo` - Configure Flux GitRepository
- `task flux:sync-all` - Force reconcile all Flux resources

### Certificate Management

- `task certificates:configure-token` - Set up Cloudflare API token
- `task certificates:apply-all` - Apply all certificate manifests
- `task certificates:status` - Check certificate status
- `task certificates:describe` - Troubleshoot certificate issues

### Monitoring & Status

- `task status` - Show deployment status
- `task health` - Comprehensive health check
- `task flux:status` - Show Flux resource status

## Important Notes

### Git as Source of Truth

**Flux requires code to be in Git**. The workflow is:

1. Make changes locally
2. Commit to Git
3. Push to remote repository
4. Flux pulls from Git and applies changes

**Never apply manifests directly with kubectl** - Always use Git + Flux.

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
- Flux provides reconciliation history

## Troubleshooting

### Flux Resources Not Reconciling

This usually means:

1. Code not pushed to Git - Run `task gitops:push`
2. GitRepository not configured - Run `task flux:configure-repo`
3. Path doesn't exist in repo - Verify paths in Flux Kustomizations/HelmReleases

### Certificates Not Issuing

1. Check Cloudflare token: `task certificates:configure-token`
2. Verify ClusterIssuer: `kubectl get clusterissuers`
3. Check certificate status: `task certificates:status`
4. Review certificate requests: `kubectl get certificaterequests -A`

### Applications Not Deploying

1. Check Flux sync status: `flux get all -n flux-system`
2. Review Flux controller logs: `kubectl logs -n flux-system -l app.kubernetes.io/name=kustomize-controller`
3. Force reconcile: `task flux:sync-all`
4. Check health: `task health`

## Best Practices

1. **Always use Taskfile** - Never run kubectl directly for deployments
2. **Commit before deploying** - Flux needs code in Git
3. **Validate before pushing** - Run `task validate:manifests` first
4. **Monitor deployments** - Use `task status` and `task health`
5. **Use GitOps workflow** - Changes → Commit → Push → Flux reconciles
