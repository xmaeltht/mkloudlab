# Service Access Guide

## ⚠️ Important: Use HTTPS, Not HTTP

All services use HTTPS with valid Let's Encrypt certificates. Always use `https://` URLs.

---

## 🌐 Services with Web UIs (Browser Access)

### ✅ Services You Can Access in Browser:

| Service | URL | Description |
|---------|-----|-------------|
| **Grafana** | https://grafana.maelkloud.com | Observability dashboards |
| **Keycloak** | https://keycloak.maelkloud.com | Identity management |
| **SonarQube** | https://sonarqube.maelkloud.com | Code quality analysis |
| **Prometheus** | https://prometheus.maelkloud.com | Metrics & monitoring |
| **Alloy** | https://alloy.maelkloud.com | Telemetry collector |

---

## ❌ Services WITHOUT Web UIs (API Only)

These services are **APIs** and don't have web interfaces. Don't try to access them in a browser:

### Tempo (http://tempo.maelkloud.com)
- **Type:** Distributed tracing backend
- **Used by:** Grafana (as a data source)
- **Access:** Only via API or Grafana
- **Why 404:** No web UI exists

### Loki (http://loki.maelkloud.com)
- **Type:** Log aggregation system
- **Used by:** Grafana (as a data source)
- **Access:** Only via API or Grafana
- **Why 404:** No web UI exists

---

## 🔧 How to Use API Services

### View Tempo Traces in Grafana

1. Open https://grafana.maelkloud.com
2. Go to **Explore**
3. Select **Tempo** as data source
4. Query traces

### View Loki Logs in Grafana

1. Open https://grafana.maelkloud.com
2. Go to **Explore**
3. Select **Loki** as data source
4. Query logs using LogQL

---

## 🐛 Troubleshooting

### "Not Secure" or Certificate Errors

**Problem:** Accessing via `http://` instead of `https://`

**Solution:**
✅ Use `https://grafana.maelkloud.com`
❌ Don't use `http://grafana.maelkloud.com`

All services have valid Let's Encrypt certificates for HTTPS.

### Pages Load Slowly

**Causes:**
1. MTU issues with Tailscale
2. Network congestion
3. Service resource constraints

**Solutions:**
```bash
# Check Tailscale connection
tailscale status | grep mkloud

# Should show "direct" not "relay"
# If relay, performance will be slower
```

### 404 Errors on Tempo/Loki

**This is normal!** These services don't have web UIs.

Use them through Grafana instead.

---

## 📋 Quick Access Checklist

- [ ] Using `https://` URLs (not `http://`)
- [ ] Only accessing services with web UIs
- [ ] Tailscale connected and showing "direct" connection
- [ ] Certificates accepted in browser

---

## 🚀 Recommended Workflow

1. **Start with Grafana:** https://grafana.maelkloud.com
   - View all metrics, logs, and traces here
   - Access Prometheus, Loki, and Tempo data sources

2. **Manage Users:** https://keycloak.maelkloud.com
   - Configure authentication
   - Manage user access

3. **Code Quality:** https://sonarqube.maelkloud.com
   - Review code analysis
   - Check security vulnerabilities

---

## 💡 Pro Tips

1. **Bookmark the HTTPS URLs** - Save yourself typing
2. **Use Grafana for everything observability** - Don't access backends directly
3. **Trust the certificates** - They're valid Let's Encrypt certs
4. **Check Tailscale status** - Ensure "direct" connection for best performance

---

## 🔗 Valid URLs Summary

Copy these to your browser:

```
https://grafana.maelkloud.com
https://keycloak.maelkloud.com
https://sonarqube.maelkloud.com
https://prometheus.maelkloud.com
https://alloy.maelkloud.com
```

**Do NOT access:**
- tempo.maelkloud.com (no web UI)
- loki.maelkloud.com (no web UI)
