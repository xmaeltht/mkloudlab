# Tailscale Setup - Private VPN Access to Monitoring Tools

## Summary

Monitoring tools (Grafana, Prometheus, Loki, Tempo, Alloy) are privately accessible via Tailscale VPN using subnet routing.

## Architecture

```
Your Device (MacBook, Phone, etc.)
  ↓
Tailscale VPN (encrypted mesh network)
  ↓
mkloud-gateway subnet router (Kubernetes operator)
  ↓
Route to 172.16.16.150 (main-gateway-istio LoadBalancer IP)
  ↓
Istio Gateway (HTTP)
  ↓
HTTPRoute (based on Host header)
  ↓
Backend Service (Grafana, Prometheus, etc.)
```

## Prerequisites

1. **Tailscale Account**: Sign up at https://tailscale.com
2. **OAuth Client**: Created in Tailscale admin console for Kubernetes operator
3. **Device with Tailscale**: Install Tailscale on your access device (MacBook, phone, etc.)

## Setup Steps

### 1. Create OAuth Client in Tailscale Admin

1. Visit https://login.tailscale.com/admin/settings/oauth
2. Click "Generate OAuth Client"
3. Select scopes:
   - `devices:write` - Allow operator to register devices
   - `routes:write` - Allow subnet route advertisement
4. Copy the OAuth Client ID and Secret
5. **DO NOT COMMIT THESE TO GIT!**

### 2. Create Kubernetes Secret

```bash
kubectl create namespace tailscale

kubectl create secret generic tailscale-operator-oauth \
  -n tailscale \
  --from-literal=client-id='YOUR_CLIENT_ID' \
  --from-literal=client-secret='YOUR_CLIENT_SECRET'
```

### 3. Deploy Tailscale Operator

```bash
# Apply all manifests
kubectl apply -f platform/networking/tailscale/

# Verify operator is running
kubectl get pods -n tailscale
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE
operator-7574b997bb-xxxxx          1/1     Running   0          1m
ts-cluster-subnet-router-xxxxx-0   1/1     Running   0          1m
```

### 4. Apply hostNetwork Patch

**CRITICAL STEP**: The subnet router needs access to the host network to reach MetalLB IPs.

```bash
# Get the StatefulSet name
STS_NAME=$(kubectl get statefulset -n tailscale -o jsonpath='{.items[0].metadata.name}')

# Apply the patch
kubectl patch statefulset $STS_NAME -n tailscale --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true},
       {"op": "add", "path": "/spec/template/spec/dnsPolicy", "value": "ClusterFirstWithHostNet"}]'
```

The pod will automatically restart with the new configuration.

### 5. Approve Subnet Routes in Tailscale Admin

1. Visit https://login.tailscale.com/admin/machines
2. Find the device named `mkloud-gateway`
3. Click on it and go to the "Routes" tab
4. Click "Approve" for the subnet route: `172.16.16.0/24`

### 6. Connect Your Device to Tailscale

```bash
# On your MacBook/laptop
tailscale up

# Verify you can see the gateway
tailscale status | grep mkloud-gateway
```

Expected output:
```
100.85.126.95  mkloud-gateway      tagged-devices  linux  active
```

### 7. Configure HTTPRoutes

The monitoring tool HTTPRoutes must accept HTTP traffic (not just HTTPS):

```bash
# Remove sectionName constraint from all observability routes
for route in alloy-route grafana-route loki-route prometheus-route tempo-route; do
  kubectl patch httproute $route -n observability --type='json' \
    -p='[{"op": "remove", "path": "/spec/parentRefs/0/sectionName"}]'
done
```

## Testing

### Access Grafana via Tailscale

```bash
# Test from command line
curl -H "Host: grafana.maelkloud.com" http://172.16.16.150

# Or from browser - configure /etc/hosts:
echo "172.16.16.150 grafana.maelkloud.com" | sudo tee -a /etc/hosts

# Then visit: http://grafana.maelkloud.com
```

### Test Other Services

```bash
# Alloy
curl -H "Host: alloy.maelkloud.com" http://172.16.16.150

# Loki (query endpoint)
curl -H "Host: loki.maelkloud.com" http://172.16.16.150/ready

# Tempo (health endpoint)
curl -H "Host: tempo.maelkloud.com" http://172.16.16.150/ready
```

## Key Configuration Details

- **Operator Version**: 1.92.x (auto-updated minor versions)
- **Subnet Router**: Advertises 172.16.16.0/24 (MetalLB pool)
- **Tailscale IP**: 100.85.126.95 (assigned by Tailscale)
- **Gateway IP**: 172.16.16.150 (MetalLB LoadBalancer)
- **Auth Method**: OAuth (client ID/secret)
- **hostname**: mkloud-gateway

## Important Notes

1. **hostNetwork Required**: Without hostNetwork, the subnet router cannot access MetalLB IPs which only exist on the host network.

2. **HTTPRoute Configuration**: Routes must NOT have `sectionName: https-*` constraints, otherwise they'll only accept HTTPS traffic and reject HTTP from Tailscale.

3. **No MagicDNS**: Currently using IP (172.16.16.150) + Host header. Could enable Tailscale MagicDNS in future for easier access (e.g., grafana.tailnet-name.ts.net).

4. **VM Tailscale Not Needed**: The Vagrant VMs do NOT need Tailscale installed. The Kubernetes operator handles everything. VM installations have been disabled.

5. **Security**:
   - Traffic encrypted via Tailscale WireGuard
   - Device authentication required
   - Can restrict access per user/device in Tailscale ACLs
   - MFA supported at Tailscale account level

## Troubleshooting

### Can't reach 172.16.16.150

**Check subnet router status:**
```bash
kubectl get pods -n tailscale
kubectl logs -n tailscale -l app=connector
```

**Verify routes approved:**
Visit Tailscale admin → Machines → mkloud-gateway → Routes

**Check hostNetwork enabled:**
```bash
kubectl get statefulset -n tailscale -o jsonpath='{.items[0].spec.template.spec.hostNetwork}'
# Should output: true
```

### 404 from Gateway

**Check HTTPRoute configuration:**
```bash
kubectl get httproute grafana-route -n observability -o yaml | grep sectionName
# Should have NO output (sectionName should be removed)
```

**Verify route is attached to gateway:**
```bash
kubectl describe httproute grafana-route -n observability
```

### Gateway IP not accessible

**Verify MetalLB assigned the IP:**
```bash
kubectl get svc main-gateway-istio -n istio-system
# EXTERNAL-IP should be 172.16.16.150
```

**Test from within cluster:**
```bash
kubectl run test --image=nicolaka/netshoot -it --rm -- \
  curl -H "Host: grafana.maelkloud.com" http://172.16.16.150
```

## Cleanup

To remove Tailscale setup:

```bash
# Delete Connector (removes device from Tailscale)
kubectl delete connector cluster-subnet-router -n tailscale

# Delete operator
kubectl delete helmrelease tailscale-operator -n tailscale

# Delete secret (optional - can keep for redeployment)
kubectl delete secret tailscale-operator-oauth -n tailscale

# Delete namespace
kubectl delete namespace tailscale
```

## Next Steps

### Optional Enhancements

1. **Tailscale MagicDNS**: Enable for easier access without Host headers
2. **Per-Service Ingress**: Individual Tailscale hostnames for each service
3. **ACL Policies**: Restrict access to specific users/devices in Tailscale admin
4. **SSH Access**: Enable Tailscale SSH for direct node access

### Service-Specific Setup

1. **Fix Prometheus**: Investigate CrashLoopBackOff (separate from networking)
2. **Loki/Tempo Paths**: Configure proper path routing if needed
3. **OAuth Proxy**: Add authentication layer for monitoring tools
4. **Grafana Dashboards**: Pre-configure cluster monitoring dashboards

## References

- Tailscale Operator: https://tailscale.com/kb/1236/kubernetes-operator
- Tailscale Subnet Router: https://tailscale.com/kb/1019/subnets
- Kubernetes Connector: https://tailscale.com/kb/1433/acls#subnet-routers
- Tailscale OAuth Clients: https://tailscale.com/kb/1215/oauth-clients
