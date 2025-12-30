# DNS Troubleshooting Guide

## Issue: DNS Resolves to Wrong IP

If DNS records are pointing to an old IP (e.g., `172.16.16.100` instead of `172.16.16.150`), follow these steps:

### 1. Check Current DNS Resolution

```bash
dig keycloak.maelkloud.com
# or
nslookup keycloak.maelkloud.com
```

### 2. Verify LoadBalancer IP

```bash
kubectl get svc main-gateway-istio -n istio-system
```

The `EXTERNAL-IP` should match the expected IP (e.g., `172.16.16.150`).

### 3. Check External-DNS Logs

```bash
kubectl logs -n networking -l app.kubernetes.io/name=external-dns --tail=50
```

Look for:
- Records being created/updated
- Errors with Cloudflare API
- Warnings about existing records

### 4. Check Cloudflare DNS Records

1. Log into Cloudflare dashboard
2. Go to DNS → Records
3. Look for A records for `*.maelkloud.com` or individual subdomains
4. Check if they point to the old IP (`172.16.16.100`)

### 5. Solutions

#### Option A: Let External-DNS Update (Recommended)

External-DNS should automatically update records. If it's not updating:

1. **Restart External-DNS** to force reconciliation:
   ```bash
   kubectl delete pod -n networking -l app.kubernetes.io/name=external-dns
   ```

2. **Check Gateway/Service Annotations**:
   ```bash
   kubectl get gateway main-gateway -n istio-system -o yaml | grep external-dns
   kubectl get svc main-gateway-istio -n istio-system -o yaml | grep external-dns
   ```

3. **Wait 2-5 minutes** for external-dns to reconcile

#### Option B: Manual Cleanup in Cloudflare

If external-dns is not updating records:

1. **Delete old DNS records** in Cloudflare:
   - Delete A records pointing to `172.16.16.100`
   - Delete individual subdomain records if they exist
   - Keep only the wildcard record `*` → `172.16.16.150`

2. **External-DNS will recreate** the correct records on next sync

#### Option C: Force External-DNS Sync

1. **Add/Update annotation** on the service to trigger sync:
   ```bash
   kubectl annotate svc main-gateway-istio -n istio-system \
     external-dns.alpha.kubernetes.io/hostname="*.maelkloud.com" \
     --overwrite
   ```

2. **Restart external-dns**:
   ```bash
   kubectl delete pod -n networking -l app.kubernetes.io/name=external-dns
   ```

### 6. Verify Fix

After applying fixes, verify:

```bash
# Check DNS resolution
dig keycloak.maelkloud.com

# Should resolve to the LoadBalancer IP (e.g., 172.16.16.150)
```

## Common Issues

### Issue: External-DNS Not Creating Records

**Symptoms**: No DNS records in Cloudflare

**Solutions**:
1. Check Cloudflare API token:
   ```bash
   kubectl get secret cloudflare-api-token-secret -n networking
   ```

2. Check external-dns logs for API errors:
   ```bash
   kubectl logs -n networking -l app.kubernetes.io/name=external-dns | grep -i error
   ```

3. Verify external-dns has `istio-gateway` in sources (already configured)

### Issue: Multiple DNS Records

**Symptoms**: Multiple A records for the same domain

**Solutions**:
1. External-DNS should manage this automatically with `policy: sync`
2. If not, manually delete duplicate records in Cloudflare
3. External-DNS will recreate the correct single record

### Issue: DNS Propagation Delay

**Symptoms**: DNS changes not visible immediately

**Solutions**:
1. DNS changes can take 2-5 minutes to propagate
2. Use different DNS servers to test:
   ```bash
   dig @8.8.8.8 keycloak.maelkloud.com
   dig @1.1.1.1 keycloak.maelkloud.com
   ```
3. Clear local DNS cache if needed

## Verification Script

Use the diagnostic script:

```bash
./scripts/fix-dns-records.sh
```

This will:
- Show current DNS resolution
- Check external-dns status
- Verify annotations
- Provide recommendations

## External-DNS Configuration

Current configuration:
- **Provider**: Cloudflare
- **Sources**: service, ingress, istio-gateway, istio-virtualservice
- **Domain Filter**: maelkloud.com
- **Policy**: sync (manages records automatically)
- **TXT Owner ID**: mkloudlab

## Manual DNS Record Creation

If external-dns is not working, you can manually create DNS records:

1. **Wildcard Record** (recommended):
   - Type: A
   - Name: `*`
   - Content: `<LoadBalancer IP>` (e.g., `172.16.16.150`)
   - Proxy: Disabled (for direct access) or Enabled (for Cloudflare proxy)
   - TTL: Auto

2. **Individual Records** (if needed):
   - Create A records for each subdomain:
     - `keycloak.maelkloud.com` → `<LoadBalancer IP>`
     - etc.

**Note**: If using Cloudflare proxy (orange cloud), ensure SSL/TLS mode is set to "Full" or "Full (strict)" for HTTPS to work.
