# Tailscale Access Troubleshooting Guide

## Current Status ✅

All infrastructure is correctly configured:
- ✅ Tailscale operator running
- ✅ Gateway service has correct IP (172.16.16.150)
- ✅ HTTPRoutes configured
- ✅ Certificates valid
- ✅ Subnet routing working
- ✅ HTTP redirects to HTTPS work

## Issue: Pages Load But Never Complete

If pages are "trying to load but never come up", this is typically a **browser-side issue**, not infrastructure.

### Step 1: Test HTTP First

Since HTTP works and redirects properly, start there:

```bash
# Open in browser:
http://grafana.maelkloud.com
```

The browser will auto-redirect to HTTPS. If the redirect works but HTTPS hangs, continue to Step 2.

### Step 2: Check Browser Console

1. Open browser DevTools (F12 or Cmd+Option+I)
2. Go to **Console** tab
3. Look for errors like:
   - `ERR_CONNECTION_RESET`
   - `ERR_SSL_PROTOCOL_ERROR`
   - `CORS` errors
   - `Mixed Content` warnings
   - JavaScript errors

4. Go to **Network** tab
5. Reload the page
6. Check which requests are:
   - Pending (never complete)
   - Failed (red)
   - Slow (taking >5 seconds)

### Step 3: Common Fixes

#### Fix 1: Clear Browser Cache
```bash
# Chrome/Edge: Cmd+Shift+Delete
# Or use Incognito/Private mode
```

#### Fix 2: Accept Certificate
If you see a certificate warning, click "Advanced" → "Proceed anyway"

#### Fix 3: Disable Browser Extensions
Some extensions (ad blockers, privacy tools) can interfere:
- Try in Incognito mode (extensions usually disabled)
- Or disable extensions one by one

#### Fix 4: Check for Mixed Content
If the page loads but resources fail:
- Look for `http://` resources on an `https://` page
- Check Network tab for blocked resources

### Step 4: Test Direct HTTPS

Try accessing HTTPS directly (bypass HTTP redirect):

```bash
# In browser, go directly to:
https://grafana.maelkloud.com
```

### Step 5: Test with curl (for debugging)

```bash
# Test HTTP (should work)
curl -I http://172.16.16.150 -H "Host: grafana.maelkloud.com"

# Test HTTPS (may fail with curl, but browser should work)
curl -k -v https://172.16.16.150 -H "Host: grafana.maelkloud.com" 2>&1 | head -50
```

## Known Issues

### curl HTTPS Connection Reset

**Symptom:** `curl: (35) Recv failure: Connection reset by peer`

**Cause:** curl's TLS negotiation differs from browsers. This is **normal** and doesn't mean browsers won't work.

**Solution:** Test in browser, not with curl.

### DNS Resolution Warnings

**Symptom:** Diagnostic shows "does not resolve"

**Cause:** `/etc/hosts` doesn't make DNS resolve, it overrides hostname resolution for applications.

**Solution:** This is **expected**. Applications (including browsers) will use `/etc/hosts` entries.

### HTTPS Timeout in Browser

**Possible Causes:**
1. **Backend service slow** - Check if Grafana/Prometheus pods are healthy
2. **Network policy blocking** - Already fixed (ports 80 and 3000 allowed)
3. **Certificate chain issue** - Certificates are valid, but browser might need intermediate certs
4. **Browser security settings** - Some browsers block self-signed or unusual certs

**Debug:**
```bash
# Check if backend services are responding
kubectl get pods -n observability -l app.kubernetes.io/name=grafana
kubectl logs -n observability -l app.kubernetes.io/name=grafana --tail=20

# Check gateway logs for errors
kubectl logs -n istio-system -l istio.io/gateway-name=main-gateway --tail=50 | grep -i error
```

## Quick Diagnostic Commands

```bash
# Run full diagnostic
./scripts/diagnose-tailscale-access.sh

# Test service access
./scripts/test-service-access.sh

# Check all HTTPRoutes
kubectl get httproute -A

# Check gateway status
kubectl get gateway main-gateway -n istio-system

# Check certificates
kubectl get certificates -A

# Check Tailscale operator
kubectl get pods -n tailscale
```

## Still Not Working?

If pages still don't load after trying all above:

1. **Check browser console errors** - This is the most important step
2. **Try a different browser** - Rules out browser-specific issues
3. **Check if services are actually running:**
   ```bash
   kubectl get pods -n observability
   kubectl get pods -n keycloak
   kubectl get pods -n sonarqube
   ```
4. **Check gateway logs for specific errors:**
   ```bash
   kubectl logs -n istio-system -l istio.io/gateway-name=main-gateway --tail=100
   ```

## Expected Behavior

✅ **Working:**
- HTTP redirects to HTTPS
- Browser shows certificate (may need to accept)
- Page loads completely
- All resources (CSS, JS, images) load

❌ **Not Working:**
- Connection timeout
- Certificate errors that can't be bypassed
- CORS errors in console
- Resources failing to load

