#!/bin/bash
# Script to help diagnose and fix DNS record issues

set -e

echo "🔍 DNS Record Diagnostic and Fix Script"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get LoadBalancer IP
LB_IP=$(kubectl get svc main-gateway-istio -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$LB_IP" ]; then
    echo -e "${RED}❌ LoadBalancer IP not found. Please ensure the main gateway service has an external IP.${NC}"
    exit 1
fi

echo "Main Gateway LoadBalancer IP: ${GREEN}$LB_IP${NC}"
echo ""

# Check current DNS resolution
echo "Current DNS Resolution:"
echo "----------------------"
DOMAINS=("keycloak.maelkloud.com" "grafana.maelkloud.com" "prometheus.maelkloud.com" "loki.maelkloud.com" "tempo.maelkloud.com" "alloy.maelkloud.com")

for DOMAIN in "${DOMAINS[@]}"; do
    if command -v dig &> /dev/null; then
        CURRENT_IP=$(dig +short $DOMAIN @8.8.8.8 2>/dev/null | head -1 || echo "not resolved")
    elif command -v nslookup &> /dev/null; then
        CURRENT_IP=$(nslookup $DOMAIN 8.8.8.8 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "not resolved")
    else
        CURRENT_IP="unknown (dig/nslookup not available)"
    fi
    
    if [ "$CURRENT_IP" = "$LB_IP" ]; then
        echo -e "${GREEN}✅ $DOMAIN → $CURRENT_IP${NC}"
    elif [ "$CURRENT_IP" = "not resolved" ]; then
        echo -e "${YELLOW}⚠️  $DOMAIN → not resolved${NC}"
    else
        echo -e "${RED}❌ $DOMAIN → $CURRENT_IP (expected $LB_IP)${NC}"
    fi
done

echo ""
echo "External-DNS Status:"
echo "-------------------"
EXTERNAL_DNS_POD=$(kubectl get pods -n networking -l app.kubernetes.io/name=external-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$EXTERNAL_DNS_POD" ]; then
    echo "Pod: $EXTERNAL_DNS_POD"
    echo ""
    echo "Recent logs (last 10 lines):"
    kubectl logs -n networking $EXTERNAL_DNS_POD --tail=10 2>/dev/null | sed 's/^/  /' || echo "  (unable to fetch logs)"
else
    echo -e "${RED}❌ External-DNS pod not found${NC}"
fi

echo ""
echo "Gateway Annotation Check:"
echo "-------------------------"
GATEWAY_ANNOTATION=$(kubectl get gateway main-gateway -n istio-system -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}' 2>/dev/null || echo "")
if [ -n "$GATEWAY_ANNOTATION" ]; then
    echo -e "${GREEN}✅ Gateway annotation: $GATEWAY_ANNOTATION${NC}"
else
    echo -e "${YELLOW}⚠️  Gateway annotation not found${NC}"
fi

SERVICE_ANNOTATION=$(kubectl get svc main-gateway-istio -n istio-system -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}' 2>/dev/null || echo "")
if [ -n "$SERVICE_ANNOTATION" ]; then
    echo -e "${GREEN}✅ Service annotation: $SERVICE_ANNOTATION${NC}"
else
    echo -e "${YELLOW}⚠️  Service annotation not found${NC}"
fi

echo ""
echo "========================================"
echo "Recommendations:"
echo ""
echo "1. If DNS records point to wrong IP (172.16.16.100):"
echo "   - Check Cloudflare dashboard for old A records"
echo "   - Delete old records pointing to 172.16.16.100"
echo "   - External-DNS should create new records pointing to $LB_IP"
echo ""
echo "2. If DNS records don't exist:"
echo "   - Wait 2-5 minutes for external-dns to create them"
echo "   - Check external-dns logs for errors"
echo "   - Verify Cloudflare API token is correct"
echo ""
echo "3. To force external-dns to reconcile:"
echo "   - Restart external-dns pod: kubectl delete pod -n networking $EXTERNAL_DNS_POD"
echo "   - Or trigger a sync by updating the gateway annotation"
echo ""
echo "4. Manual DNS update (if needed):"
echo "   - Go to Cloudflare dashboard"
echo "   - Delete old A records for *.maelkloud.com or individual subdomains"
echo "   - Create new A record: * → $LB_IP (or individual subdomains → $LB_IP)"
echo ""
