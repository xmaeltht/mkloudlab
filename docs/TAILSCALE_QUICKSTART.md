# Tailscale Quick Start Guide

Get your services accessible from anywhere in 5 minutes using Tailscale VPN.

## Prerequisites

- [ ] Tailscale account (free at https://tailscale.com)
- [ ] Tailscale installed on your device
- [ ] Kubernetes cluster running (your Vagrant VMs)

## Quick Setup (Recommended Path)

### Step 1: Install Tailscale on VMs (2 minutes)

```bash
cd /Users/mael/workspace/kubernetes/mkloudlab
./scripts/setup-tailscale-host.sh
```

### Step 2: Configure Subnet Routing (2 minutes)

```bash
cd infrastructure/vagrant

# Start Tailscale on kcontroller
vagrant ssh kcontroller -c 'sudo tailscale up --advertise-routes=172.16.16.0/24 --accept-routes --hostname=mkloud-kcontroller'

# Visit the auth URL shown above, then approve subnet route:
# 1. Go to https://login.tailscale.com/admin/machines
# 2. Find 'mkloud-kcontroller'
# 3. Click '...' → Edit route settings
# 4. Enable subnet route for 172.16.16.0/24
```

### Step 3: Configure DNS on Your Device (1 minute)

Add to `/etc/hosts` on your Mac/laptop:

```bash
echo "172.16.16.150  keycloak.maelkloud.com grafana.maelkloud.com prometheus.maelkloud.com loki.maelkloud.com tempo.maelkloud.com alloy.maelkloud.com" | sudo tee -a /etc/hosts
```

### Step 4: Test Access ✅

```bash
# Verify setup
./scripts/verify-tailscale-access.sh

# Access services from anywhere!
open https://keycloak.maelkloud.com
open https://grafana.maelkloud.com
```

## That's It! 🎉

You can now access all your services from:
- Your laptop (anywhere with internet)
- Your phone (install Tailscale app)
- Any device on your Tailscale network

## Advanced Setup (Optional)

Want more control? See the full guide: [TAILSCALE_SETUP.md](./TAILSCALE_SETUP.md)

### Option: Tailscale Kubernetes Operator

For direct service exposure with auto-generated hostnames:

```bash
# 1. Create OAuth client at https://login.tailscale.com/admin/settings/oauth
# 2. Create secret
kubectl create secret generic operator-oauth \
  --namespace=tailscale \
  --from-literal=client-id='<YOUR_CLIENT_ID>' \
  --from-literal=client-secret='<YOUR_CLIENT_SECRET>'

# 3. Deploy operator
flux reconcile kustomization platform-networking

# 4. Expose gateway
kubectl apply -f platform/networking/tailscale/ingress-service.yaml
```

## Troubleshooting

### Can't reach 172.16.16.x addresses

1. Check Tailscale is running: `tailscale status`
2. Verify subnet route is approved in Tailscale admin console
3. Test connectivity: `ping 172.16.16.100`

### Services not responding

1. Check MetalLB: `kubectl get svc -n istio-system main-gateway-istio`
2. Verify gateway pods: `kubectl get pods -n istio-system`
3. Check from inside cluster: `vagrant ssh kcontroller -c 'curl http://172.16.16.150'`

### Certificate warnings

Your services use Let's Encrypt certs for `*.maelkloud.com`. The browser may show warnings if you:
- Haven't configured DNS properly
- Are using IP addresses directly

Solution: Use the proper domain names via `/etc/hosts`

## Access from Mobile

1. Install Tailscale app on your phone
2. Connect to your Tailscale network
3. Add DNS entries to Tailscale DNS settings or use `http://172.16.16.150`
4. Access services!

## Security Notes

- ✅ Services are **NOT** exposed to the public internet
- ✅ Only accessible via your Tailscale VPN
- ✅ All traffic is encrypted by Tailscale
- ✅ You control who has access via Tailscale admin console

## Next Steps

- [ ] Set up Tailscale on your mobile device
- [ ] Configure Tailscale ACLs for fine-grained access control
- [ ] Add more devices to your Tailscale network
- [ ] Explore Tailscale's MagicDNS for easier service discovery

---

**Documentation:**
- Full setup guide: [TAILSCALE_SETUP.md](./TAILSCALE_SETUP.md)
- Tailscale docs: https://tailscale.com/kb/
