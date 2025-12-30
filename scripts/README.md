# Scripts Directory

This directory contains utility scripts for managing and troubleshooting the mkloudlab Kubernetes cluster.

## Setup & Installation Scripts

### install-prerequisites.sh

**Purpose:** Install core cluster prerequisites before Flux installation

**What it installs:**
- Gateway API CRDs
- local-path storage provisioner
- metrics-server
- cert-manager
- Let's Encrypt ClusterIssuers (HTTP-01 and DNS-01)
- istio-system namespace (Istio itself is managed by Flux)

**Usage:**
```bash
# Automated via Taskfile (recommended)
task install:prerequisites

# Or run directly
./scripts/install-prerequisites.sh
```

**Environment Variables:**
- `CLOUDFLARE_API_TOKEN` - Optional. If set, creates DNS-01 ClusterIssuer for Cloudflare

**When to use:**
- Initial cluster setup
- After cluster reset
- When prerequisites are missing

**Note:** Istio service mesh is now managed by Flux (`platform/flux/apps/istio.yaml`), not installed by this script.

---

### install-k9s-plugins.sh

**Purpose:** Install K9s plugins for Flux CD keyboard shortcuts

**What it does:**
- Installs Flux-specific K9s plugins
- Adds keyboard shortcuts for common Flux operations
- Configures K9s to work seamlessly with Flux resources

**Usage:**
```bash
# Automated via Taskfile (recommended)
task install:k9s-plugins

# Or run directly
./scripts/install-k9s-plugins.sh
```

**When to use:**
- After installing K9s
- When setting up a new development machine
- If K9s plugins are missing or outdated

---

## Diagnostic & Verification Scripts

### verify-domain-access.sh

**Purpose:** Comprehensive verification of domain-based access setup

**What it checks:**
- ✅ Main Gateway status and configuration
- ✅ LoadBalancer service and IP assignment
- ✅ HTTPRoutes for all services (keycloak, grafana, prometheus, loki, tempo, alloy)
- ✅ Certificate status (cert-manager)
- ✅ External-DNS pod status and logs
- ✅ MetalLB controller status
- ✅ DNS resolution for all domains

**Usage:**
```bash
./scripts/verify-domain-access.sh
```

**When to use:**
- After deploying services
- When troubleshooting access issues
- To verify certificate issuance
- After DNS changes

**Output:** Color-coded status with actionable recommendations

---

### verify-tailscale-access.sh

**Purpose:** End-to-end verification of Tailscale access to Kubernetes services

**What it checks:**
- ✅ Local Tailscale installation and connectivity
- ✅ Subnet route connectivity to cluster
- ✅ MetalLB gateway reachability
- ✅ Service HTTPS endpoints (all services)
- ✅ Tailscale Kubernetes operator status
- ✅ Tailscale LoadBalancer services
- ✅ DNS configuration (/etc/hosts)
- ✅ End-to-end service test

**Usage:**
```bash
./scripts/verify-tailscale-access.sh
```

**When to use:**
- After Tailscale setup
- When troubleshooting remote access
- To verify subnet routing
- When services are unreachable via Tailscale

**Prerequisites:**
- Tailscale installed on your machine
- Subnet routing configured and approved
- Or Tailscale operator deployed in cluster

---

### diagnose-tailscale-access.sh

**Purpose:** Diagnose Tailscale connectivity issues with detailed checks

**What it checks:**
- 🔍 Tailscale connectivity and status
- 🔍 Subnet route to cluster (172.16.16.100)
- 🔍 MetalLB IP reachability (172.16.16.150)
- 🔍 /etc/hosts configuration
- 🔍 DNS resolution for all domains
- 🔍 HTTP connectivity to gateway
- 🔍 Kubernetes resources (gateway, routes, operator)

**Usage:**
```bash
./scripts/diagnose-tailscale-access.sh
```

**When to use:**
- When services are loading but not completing
- When troubleshooting Tailscale issues
- Before running verify-tailscale-access.sh
- To identify specific connectivity problems

**Output:** Detailed diagnostic information with troubleshooting steps

---

### test-service-access.sh

**Purpose:** Quick test of service accessibility via Tailscale

**What it tests:**
- HTTP endpoints (should redirect to HTTPS)
- HTTPS endpoints for grafana, prometheus, keycloak
- Connection response codes

**Usage:**
```bash
./scripts/test-service-access.sh
```

**When to use:**
- Quick smoke test after deployment
- Before opening browser
- To verify services are responding

**Note:** This is a lightweight test. For comprehensive verification, use `verify-tailscale-access.sh`

---

## Script Categories

### Setup & Installation
- `install-prerequisites.sh` - Core cluster prerequisites
- `install-k9s-plugins.sh` - K9s Flux plugins

### Tailscale Diagnostics
- `verify-tailscale-access.sh` - Complete Tailscale verification
- `diagnose-tailscale-access.sh` - Detailed Tailscale diagnostics
- `test-service-access.sh` - Quick service test

### Domain & Gateway Verification
- `verify-domain-access.sh` - Complete domain access verification

---

## Common Troubleshooting Workflows

### Problem: Services not accessible

1. **Check domain access:**
   ```bash
   ./scripts/verify-domain-access.sh
   ```

2. **If using Tailscale, diagnose connectivity:**
   ```bash
   ./scripts/diagnose-tailscale-access.sh
   ```

3. **Run comprehensive Tailscale verification:**
   ```bash
   ./scripts/verify-tailscale-access.sh
   ```

### Problem: Certificates not issuing

```bash
./scripts/verify-domain-access.sh
# Check section: "4. Checking Certificates..."
# Then verify cert-manager logs:
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

### Problem: DNS not resolving

```bash
./scripts/verify-domain-access.sh
# Check section: "7. DNS Resolution Test..."
# Verify external-dns logs:
kubectl logs -n networking -l app.kubernetes.io/name=external-dns --tail=50
```

### Problem: HTTPRoutes misconfigured

```bash
./scripts/verify-domain-access.sh
# Check section: "3. Checking HTTPRoutes..."
# All routes should point to main-gateway in istio-system namespace
```

---

## Integration with Taskfile

Many scripts are integrated with the Taskfile for easier execution:

```bash
# Instead of ./scripts/install-prerequisites.sh
task install:prerequisites

# Instead of ./scripts/install-k9s-plugins.sh
task install:k9s-plugins

# For comprehensive health check
task health

# For gateway status
task gateway:status

# For certificate status
task certificates:status
```

See `task --list-all` for all available tasks.

---

## Maintenance

### Adding New Scripts

When adding new scripts:
1. Make them executable: `chmod +x scripts/your-script.sh`
2. Add shebang: `#!/bin/bash`
3. Add error handling: `set -e` or `set -euo pipefail`
4. Document in this README
5. Consider adding to Taskfile if frequently used

### Script Naming Convention

- `install-*.sh` - Installation/setup scripts
- `verify-*.sh` - Verification/validation scripts
- `diagnose-*.sh` - Detailed diagnostic scripts
- `test-*.sh` - Quick test scripts

---

## See Also

- [Taskfile.yml](../Taskfile.yml) - Task automation
- [platform/networking/tailscale/SETUP.md](../platform/networking/tailscale/SETUP.md) - Tailscale setup guide
- [infrastructure/terraform/](../infrastructure/terraform/) - Terraform/OpenTofu configurations
