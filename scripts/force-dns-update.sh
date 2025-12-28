#!/bin/bash
# Script to force external-dns to update DNS records

set -e

echo "🔄 Forcing External-DNS to Update DNS Records"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get LoadBalancer IP
LB_IP=$(kubectl get svc main-gateway-istio -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$LB_IP" ]; then
    echo -e "${RED}❌ LoadBalancer IP not found${NC}"
    exit 1
fi

echo "Current LoadBalancer IP: ${GREEN}$LB_IP${NC}"
echo ""

# Method 1: Restart external-dns pod
echo "Method 1: Restarting External-DNS pod..."
EXTERNAL_DNS_POD=$(kubectl get pods -n networking -l app.kubernetes.io/name=external-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$EXTERNAL_DNS_POD" ]; then
    echo "Deleting pod: $EXTERNAL_DNS_POD"
    kubectl delete pod -n networking $EXTERNAL_DNS_POD
    echo -e "${GREEN}✅ External-DNS pod restarted${NC}"
    echo "Waiting for pod to be ready..."
    kubectl wait --for=condition=ready pod -n networking -l app.kubernetes.io/name=external-dns --timeout=60s
    echo -e "${GREEN}✅ External-DNS pod is ready${NC}"
else
    echo -e "${RED}❌ External-DNS pod not found${NC}"
fi

echo ""
echo "Method 2: Triggering annotation update..."
# Update annotation to trigger reconciliation
kubectl annotate svc main-gateway-istio -n istio-system \
  external-dns.alpha.kubernetes.io/hostname="*.maelkloud.com" \
  --overwrite > /dev/null 2>&1

echo -e "${GREEN}✅ Service annotation updated${NC}"

echo ""
echo "Waiting 30 seconds for external-dns to process..."
sleep 30

echo ""
echo "Checking external-dns logs..."
echo "-----------------------------"
kubectl logs -n networking -l app.kubernetes.io/name=external-dns --tail=10 | sed 's/^/  /'

echo ""
echo "=============================================="
echo -e "${GREEN}✅ External-DNS reconciliation triggered${NC}"
echo ""
echo "Next steps:"
echo "1. Wait 2-5 minutes for DNS propagation"
echo "2. Check DNS resolution: dig keycloak.maelkloud.com"
echo "3. If still wrong, manually update DNS records in Cloudflare:"
echo "   - Delete old A records pointing to 172.16.16.100"
echo "   - External-DNS will recreate records pointing to $LB_IP"
echo ""
echo "To check Cloudflare DNS records manually:"
echo "1. Go to Cloudflare Dashboard → DNS → Records"
echo "2. Look for A records for *.maelkloud.com or individual subdomains"
echo "3. Update or delete records pointing to 172.16.16.100"
echo ""

