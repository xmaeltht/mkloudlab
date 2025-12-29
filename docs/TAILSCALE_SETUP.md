# Tailscale Setup for mkloudlab

This guide explains how to access your Kubernetes services from anywhere using Tailscale VPN.

## Overview

Your setup will have two access methods:

1. **Host-level access**: Access the cluster network (172.16.16.0/24) via subnet routing
2. **Service-level access**: Direct access to services via Tailscale LoadBalancer

## Architecture

```
Internet (Your Device)
    ↓
Tailscale VPN
    ↓
┌─────────────────────────────────────────────────┐
│ kcontroller (Subnet Router)                     │
│ - Advertises: 172.16.16.0/24                    │
│ - IP: 172.16.16.100                             │
└─────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────┐
│ Kubernetes Cluster (172.16.16.0/24)             │
│                                                  │
│  MetalLB (172.16.16.150)                        │
│      ↓                                           │
│  Istio Gateway (main-gateway)                   │
│      ↓                                           │
│  HTTPRoutes                                      │
│      ↓                                           │
│  Services (Keycloak, Grafana, etc.)             │
└─────────────────────────────────────────────────┘
```

## Part 1: Host-Level Access (Subnet Routing)

### Step 1: Install Tailscale on Vagrant VMs

Run the setup script from your Mac:

```bash
cd /Users/mael/workspace/kubernetes/mkloudlab
./scripts/setup-tailscale-host.sh
```

This will:
- Copy the installation script to all VMs
- Install Tailscale on each VM
- Enable IP forwarding for subnet routing

### Step 2: Configure kcontroller as Subnet Router

Start Tailscale on the controller node to advertise the cluster network:

```bash
cd /Users/mael/workspace/kubernetes/mkloudlab/infrastructure/vagrant
vagrant ssh kcontroller -c 'sudo tailscale up --advertise-routes=172.16.16.0/24 --accept-routes --hostname=mkloud-kcontroller'
```

You'll see output like:
```
To authenticate, visit:
  https://login.tailscale.com/a/1234567890abc
```

1. Visit the URL and authenticate with your Tailscale account
2. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
3. Find `mkloud-kcontroller`
4. Click the `...` menu → **Edit route settings**
5. **Enable** the subnet route for `172.16.16.0/24`

### Step 3: Test Connectivity

From your Mac (or any device on your Tailscale network):

```bash
# Test connection to kcontroller
ping 172.16.16.100

# Test connection to MetalLB gateway
curl -I http://172.16.16.150

# Access services via their MetalLB IP
curl -k https://172.16.16.150 -H "Host: keycloak.maelkloud.com"
```

### Step 4: Configure Local DNS (Optional)

Add to your `/etc/hosts` on your Mac:

```
172.16.16.150  keycloak.maelkloud.com
172.16.16.150  grafana.maelkloud.com
172.16.16.150  prometheus.maelkloud.com
172.16.16.150  loki.maelkloud.com
172.16.16.150  tempo.maelkloud.com
172.16.16.150  alloy.maelkloud.com
```

Now you can access services using their domain names:
```bash
open https://keycloak.maelkloud.com
open https://grafana.maelkloud.com
```

---

## Part 2: Service-Level Access (Kubernetes Operator)

This provides direct access to services with auto-generated Tailscale hostnames.

### Step 1: Create Tailscale OAuth Client

1. Go to https://login.tailscale.com/admin/settings/oauth
2. Click **Generate OAuth Client**
3. Configuration:
   - **Tags**: `tag:k8s`
   - **Description**: `mkloud Kubernetes Operator`
   - **Scopes**: Leave default (all scopes)
4. Copy the **Client ID** and **Client Secret**

### Step 2: Create Kubernetes Secret

```bash
kubectl create namespace tailscale

kubectl create secret generic operator-oauth \
  --namespace=tailscale \
  --from-literal=client-id='<YOUR_CLIENT_ID>' \
  --from-literal=client-secret='<YOUR_CLIENT_SECRET>'
```

### Step 3: Deploy Tailscale Operator

The operator is already configured in your Flux setup:

```bash
# Verify the resources are in kustomization
cat platform/networking/kustomization.yaml

# Force Flux to reconcile
flux reconcile kustomization platform-networking
```

### Step 4: Verify Operator Installation

```bash
# Check operator pod
kubectl get pods -n tailscale

# Check operator logs
kubectl logs -n tailscale -l app=tailscale-operator -f

# Should see: "Operator is running"
```

### Step 5: Expose Main Gateway via Tailscale

The ingress service is already created at `platform/networking/tailscale/ingress-service.yaml`.

Apply it:

```bash
kubectl apply -f platform/networking/tailscale/ingress-service.yaml
```

This creates a LoadBalancer service with `loadBalancerClass: tailscale`, which:
- Creates a Tailscale proxy pod
- Assigns a Tailscale IP to the service
- Makes it accessible as `mkloud-gateway` on your Tailscale network

### Step 6: Access Services via Tailscale

```bash
# Get the Tailscale hostname
kubectl get svc -n istio-system main-gateway-tailscale

# Access services via Tailscale
# Format: https://mkloud-gateway.<your-tailnet>.ts.net
curl https://mkloud-gateway/
```

Since the gateway uses SNI routing, you still need to provide the Host header:

```bash
curl https://mkloud-gateway.<tailnet>.ts.net -H "Host: keycloak.maelkloud.com"
```

---

## Part 3: Complete Integration (Both Methods)

### Option A: Subnet Routing (Recommended for Homelab)

**Pros:**
- Access all cluster IPs directly
- No additional pods needed
- Easy to debug with kubectl
- Works with /etc/hosts for custom domains

**Cons:**
- Requires subnet route approval in Tailscale
- Need to manage /etc/hosts manually

**Best for:**
- Development and testing
- Direct cluster access
- Running kubectl from anywhere

### Option B: Service LoadBalancer (Recommended for Production)

**Pros:**
- Each service gets its own Tailscale hostname
- No subnet routes needed
- Auto-managed by Kubernetes

**Cons:**
- Extra proxy pod per exposed service
- Still need Host headers for SNI routing

**Best for:**
- Exposing specific services
- Production-like access control
- Service-level ACLs in Tailscale

### Option C: Both (Maximum Flexibility)

Use subnet routing for cluster management and service LBs for external access:

1. **Management access**: Via subnet routing to cluster IPs
2. **Service access**: Via Tailscale LoadBalancers with friendly hostnames

---

## Access Summary

### Via Subnet Routing
```bash
# Add to /etc/hosts
echo "172.16.16.150  keycloak.maelkloud.com grafana.maelkloud.com" | sudo tee -a /etc/hosts

# Access services
open https://keycloak.maelkloud.com
open https://grafana.maelkloud.com
```

### Via Tailscale Hostnames
```bash
# Access via auto-generated Tailscale names
open https://mkloud-gateway.<tailnet>.ts.net

# With Host header
curl https://mkloud-gateway.<tailnet>.ts.net -H "Host: keycloak.maelkloud.com"
```

---

## Troubleshooting

### Subnet route not working

```bash
# On kcontroller
sudo tailscale status

# Should show:
# - Peer with subnet routes enabled
# - IP: 172.16.16.0/24

# Check IP forwarding
sysctl net.ipv4.ip_forward  # Should be 1
```

### Operator not creating proxy

```bash
# Check operator logs
kubectl logs -n tailscale -l app=tailscale-operator

# Check service annotation
kubectl get svc main-gateway-tailscale -n istio-system -o yaml

# Verify OAuth secret
kubectl get secret operator-oauth -n tailscale
```

### Cannot access services

```bash
# Test MetalLB
kubectl get svc -n istio-system main-gateway-istio

# Test from kcontroller
vagrant ssh kcontroller -c 'curl -I http://172.16.16.150'

# Test Tailscale connectivity
tailscale status
tailscale ping mkloud-kcontroller
```

---

## Security Considerations

### Tailscale ACLs

Update your Tailscale ACL to control access:

```json
{
  "tagOwners": {
    "tag:k8s": ["your-email@example.com"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:k8s:*"]
    }
  ]
}
```

### Network Policies

Your existing Kyverno network policies still apply. Tailscale traffic enters through:
- Subnet routing: No change (uses existing paths)
- LoadBalancer: Goes through Tailscale proxy → Gateway → Services

---

## Next Steps

1. ✅ Install Tailscale on VMs
2. ✅ Configure subnet routing
3. ✅ Deploy Tailscale operator
4. ✅ Expose services via LoadBalancer
5. 🔧 Configure MagicDNS (optional)
6. 🔧 Set up Tailscale ACLs
7. 🔧 Enable HTTPS with your existing certs

---

## Additional Resources

- [Tailscale Kubernetes Operator Docs](https://tailscale.com/kb/1236/kubernetes-operator)
- [Subnet Routing Guide](https://tailscale.com/kb/1019/subnets)
- [Tailscale ACLs](https://tailscale.com/kb/1018/acls)
