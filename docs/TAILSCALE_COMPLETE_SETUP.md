# Tailscale Complete Setup - mkloudlab

**Date:** December 27, 2025
**Status:** ✅ Fully Operational

---

## 🎯 Overview

Your Kubernetes cluster is now accessible from anywhere via Tailscale VPN with two access methods:
1. **Subnet Routing** (faster, recommended)
2. **Tailscale Kubernetes Operator** (service-specific access)

---

## 📊 Performance Comparison

| Access Method | Speed | Connection Type | Best For |
|--------------|-------|-----------------|----------|
| **Subnet Routing** | ~71ms | Direct | ✅ Daily use, best performance |
| **Tailscale LoadBalancer** | ~196ms | Relayed | Service isolation, ACL control |

**Recommendation:** Use subnet routing via `/etc/hosts` for best performance!

---

## 🌐 Current Configuration

### Tailscale Network

| Device | IP | Type | Status |
|--------|-----|------|--------|
| macbook-pro-2 | 100.70.64.108 | User device | Connected |
| mkloud-kcontroller | 100.76.207.89 | Subnet router | ✅ Direct connection |
| mkloud (operator) | 100.66.111.40 | Operator | Running |
| mkloud-gateway | 100.106.63.26 | Service proxy | Relayed |

### Subnet Routes

- **172.16.16.0/24** - Kubernetes cluster network (advertised by kcontroller)

### Services Exposed

All services accessible via:
- **IP**: 172.16.16.150 (MetalLB)
- **Domains** (via /etc/hosts):
  - keycloak.maelkloud.com
  - grafana.maelkloud.com
  - prometheus.maelkloud.com
  - loki.maelkloud.com
  - tempo.maelkloud.com
  - alloy.maelkloud.com

---

## 🚀 Access Methods

### Method 1: Subnet Routing (Recommended)

**How it works:**
- Tailscale creates a secure tunnel to kcontroller
- kcontroller routes traffic to the entire 172.16.16.0/24 network
- Direct connection = fastest performance

**Access services:**
```bash
# Via domain names (using /etc/hosts)
open http://grafana.maelkloud.com
open http://keycloak.maelkloud.com

# Or via IP with Host header
curl -H "Host: grafana.maelkloud.com" http://172.16.16.150
```

**Performance:** ~71ms response time

**Requirements:**
- ✅ Tailscale running on your device
- ✅ Subnet route 172.16.16.0/24 approved in Tailscale admin
- ✅ Entries in /etc/hosts (see Configuration section)

---

### Method 2: Tailscale LoadBalancer

**How it works:**
- Each service gets its own Tailscale proxy pod
- Operator manages authentication and routing
- Services get unique Tailscale hostnames

**Access services:**
```bash
# Via Tailscale hostname
curl -H "Host: grafana.maelkloud.com" http://mkloud-gateway.tailfd44c8.ts.net

# With MagicDNS enabled
curl -H "Host: grafana.maelkloud.com" http://mkloud-gateway
```

**Performance:** ~196ms response time (currently relayed)

**Requirements:**
- ✅ Tailscale operator deployed
- ✅ OAuth credentials configured
- ✅ ACL tags: tag:k8s, tag:k8s-operator

---

## ⚙️ Configuration Details

### On Your Mac (/etc/hosts)

```
172.16.16.150  keycloak.maelkloud.com grafana.maelkloud.com prometheus.maelkloud.com loki.maelkloud.com tempo.maelkloud.com alloy.maelkloud.com
```

### Tailscale ACLs

```json
{
  "tagOwners": {
    "tag:k8s": ["autogroup:admin"],
    "tag:k8s-operator": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:k8s:*", "tag:k8s-operator:*"]
    }
  ]
}
```

### Tailscale OAuth Credentials

- **Client ID:** k9cJv3aXZe11CNTRL
- **Secret:** (stored in Kubernetes secret `operator-oauth` in namespace `tailscale`)

---

## 📱 Access from Other Devices

### Mobile/Tablet Access

1. **Install Tailscale app** (iOS/Android)
2. **Sign in** with the same Tailscale account
3. **Access services:**
   - Via IP: http://172.16.16.150
   - With Host header or configure local DNS

### Another Computer

1. **Install Tailscale**
2. **Connect** to your Tailscale network
3. **Add to /etc/hosts** (Linux/Mac) or hosts file (Windows)
4. **Access services** using domain names

---

## 🛠️ Deployed Components

### Kubernetes Resources

**Namespace: tailscale**
```bash
kubectl get all -n tailscale
```

- **Operator Deployment:** `operator-6df68f5f59-6fbf9` (2/2 Running)
- **HelmRelease:** `tailscale-operator` (v1.78.3)
- **Secret:** `operator-oauth` (OAuth credentials)

**Namespace: istio-system**
```bash
kubectl get svc -n istio-system | grep gateway
```

- **main-gateway-istio:** MetalLB LoadBalancer (172.16.16.150)
- **main-gateway-tailscale:** Tailscale LoadBalancer (mkloud-gateway.tailfd44c8.ts.net)

### Vagrant VMs

All VMs have Tailscale installed:

```bash
# Check status on any VM
cd /Users/mael/workspace/kubernetes/mkloudlab/infrastructure/vagrant
vagrant ssh kcontroller -c 'sudo tailscale status'
```

- **kcontroller:** Subnet router (advertises 172.16.16.0/24)
- **knode1-3:** Worker nodes (Tailscale installed but not routing)

---

## 🔧 Troubleshooting

### Services are slow

**Current status:** Services are responding in ~71ms via subnet routing, which is good.

If you experience slowness:

1. **Check connection type:**
   ```bash
   tailscale status | grep mkloud
   ```
   Look for "direct" (fast) vs "relay" (slower)

2. **Test latency:**
   ```bash
   tailscale ping mkloud-kcontroller
   ```

3. **Verify subnet route:**
   - Go to https://login.tailscale.com/admin/machines
   - Check that 172.16.16.0/24 is approved for kcontroller

### Cannot access services

1. **Check Tailscale is running:**
   ```bash
   tailscale status
   ```

2. **Verify connectivity:**
   ```bash
   ping 172.16.16.100  # Should reach kcontroller
   ping 172.16.16.150  # May not respond (gateway doesn't answer ICMP)
   curl http://172.16.16.150  # Should get a response
   ```

3. **Check /etc/hosts:**
   ```bash
   cat /etc/hosts | grep maelkloud.com
   ```

4. **Verify services are running:**
   ```bash
   kubectl get pods -n istio-system
   kubectl get svc -n istio-system main-gateway-istio
   ```

### Operator pod crashing

**Check logs:**
```bash
kubectl logs -n tailscale -l app=operator -c operator
```

**Common issues:**
- Missing ACL tags (tag:k8s-operator)
- Invalid OAuth credentials
- Network connectivity from cluster

---

## 📈 Advanced Features

### Enable MagicDNS

1. Go to: https://login.tailscale.com/admin/dns
2. Click **Enable MagicDNS**
3. Benefits:
   - Use `mkloud-kcontroller` instead of IP
   - Use `mkloud-gateway` instead of full hostname
   - Automatic DNS for all Tailscale devices

### Expose Individual Services

To expose a specific service via Tailscale LoadBalancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: my-namespace
  annotations:
    tailscale.com/hostname: "mkloud-myservice"
    tailscale.com/tags: "tag:k8s"
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: my-app
```

### Configure Tailscale ACLs

Fine-grained access control:

```json
{
  "tagOwners": {
    "tag:k8s": ["user@example.com"],
    "tag:k8s-operator": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["user@example.com"],
      "dst": ["tag:k8s:80,443"]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:k8s-operator:*"]
    }
  ]
}
```

---

## 🔒 Security

### Current Security Posture

✅ **Services NOT exposed to public internet**
- Only accessible via Tailscale VPN
- No public IP addresses assigned
- No port forwarding on router needed

✅ **Encrypted traffic**
- All Tailscale traffic is end-to-end encrypted
- WireGuard protocol (modern, fast, secure)

✅ **Access control**
- Controlled via Tailscale admin console
- ACL-based permissions
- Device authentication required

### Recommendations

1. **Enable MFA** on your Tailscale account
2. **Regular ACL reviews** - ensure only authorized users have access
3. **Monitor connected devices** in Tailscale admin console
4. **Keep Tailscale updated** on all devices
5. **Use device authorization** to approve new devices manually

---

## 📚 Useful Commands

### Tailscale Management

```bash
# Check status
tailscale status

# Ping a device
tailscale ping mkloud-kcontroller

# Network diagnostics
tailscale netcheck

# View routes
tailscale status --json | jq '.Peer[].PrimaryRoutes'

# Disconnect
sudo tailscale down

# Reconnect
sudo tailscale up
```

### Kubernetes Operations

```bash
# Check operator
kubectl get pods -n tailscale
kubectl logs -n tailscale -l app=operator -c operator

# Check services
kubectl get svc -A --field-selector spec.type=LoadBalancer

# Check Tailscale LoadBalancers
kubectl get svc -A -o json | jq -r '.items[] | select(.spec.loadBalancerClass == "tailscale") | "\(.metadata.namespace)/\(.metadata.name): \(.status.loadBalancer.ingress[0].hostname)"'

# Force operator reconciliation
kubectl delete pod -n tailscale -l app=operator
```

### Verification

```bash
# Run complete verification
/Users/mael/workspace/kubernetes/mkloudlab/scripts/verify-tailscale-access.sh

# Quick service test
curl -I http://grafana.maelkloud.com
curl -I http://keycloak.maelkloud.com
```

---

## 📖 Documentation Files

- **This file:** Complete setup reference
- **TAILSCALE_QUICKSTART.md:** 5-minute quick start guide
- **TAILSCALE_SETUP.md:** Detailed setup instructions
- **Scripts:**
  - `scripts/setup-tailscale-host.sh` - Install on VMs
  - `scripts/verify-tailscale-access.sh` - Test connectivity
  - `infrastructure/vagrant/install-tailscale.sh` - VM installation script

---

## 🎓 Learning Resources

- [Tailscale Documentation](https://tailscale.com/kb/)
- [Subnet Routers](https://tailscale.com/kb/1019/subnets)
- [Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator)
- [ACL Syntax](https://tailscale.com/kb/1018/acls)
- [MagicDNS](https://tailscale.com/kb/1081/magicdns)

---

## ✅ Checklist: You're All Set!

- ✅ Tailscale installed on all VMs
- ✅ Subnet routing configured (172.16.16.0/24)
- ✅ Tailscale connected on your Mac
- ✅ DNS configured via /etc/hosts
- ✅ All services accessible (tested)
- ✅ Tailscale operator deployed
- ✅ OAuth credentials configured
- ✅ ACLs configured
- ✅ LoadBalancer service deployed
- ✅ Performance verified (~71ms via subnet routing)

---

## 🎉 Summary

You can now access all your Kubernetes services from anywhere:

**From your Mac:**
```bash
open http://grafana.maelkloud.com
open http://keycloak.maelkloud.com
```

**From your phone:**
1. Install Tailscale app
2. Connect to your network
3. Use http://172.16.16.150 with appropriate Host headers

**Performance:** ~71ms response time (excellent!)

**Security:** Private VPN access only, fully encrypted

Enjoy your secure, remote access to your homelab! 🚀
