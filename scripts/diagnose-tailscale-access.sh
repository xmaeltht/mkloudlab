#!/bin/bash
# Comprehensive Tailscale Access Diagnostic Script

set -euo pipefail

echo "=== Tailscale Access Diagnostic ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Tailscale connectivity
echo "1. Checking Tailscale connectivity..."
if command -v tailscale &> /dev/null; then
    if tailscale status &> /dev/null; then
        echo -e "${GREEN}✓${NC} Tailscale is running"
        tailscale status | head -5
    else
        echo -e "${RED}✗${NC} Tailscale is not connected"
    fi
else
    echo -e "${YELLOW}⚠${NC} Tailscale CLI not found (this is OK if using GUI)"
fi
echo ""

# Check 2: Subnet route connectivity
echo "2. Testing subnet route to cluster..."
if ping -c 1 -W 2 172.16.16.100 &> /dev/null; then
    echo -e "${GREEN}✓${NC} Can reach kcontroller (172.16.16.100)"
else
    echo -e "${RED}✗${NC} Cannot reach kcontroller - subnet route may not be working"
    echo "   Check: Tailscale admin console → Machines → kcontroller → Enable subnet route"
fi

if ping -c 1 -W 2 172.16.16.150 &> /dev/null; then
    echo -e "${GREEN}✓${NC} Can reach MetalLB IP (172.16.16.150)"
else
    echo -e "${YELLOW}⚠${NC} Cannot ping 172.16.16.150 (gateway may not respond to ICMP)"
fi
echo ""

# Check 3: /etc/hosts configuration
echo "3. Checking /etc/hosts configuration..."
if grep -q "172.16.16.150.*maelkloud.com" /etc/hosts 2>/dev/null; then
    echo -e "${GREEN}✓${NC} /etc/hosts has entries for maelkloud.com"
    grep "172.16.16.150.*maelkloud.com" /etc/hosts
else
    echo -e "${RED}✗${NC} /etc/hosts missing entries!"
    echo "   Run: echo '172.16.16.150  keycloak.maelkloud.com sonarqube.maelkloud.com grafana.maelkloud.com prometheus.maelkloud.com loki.maelkloud.com tempo.maelkloud.com alloy.maelkloud.com' | sudo tee -a /etc/hosts"
fi
echo ""

# Check 4: DNS resolution
echo "4. Testing DNS resolution..."
for domain in keycloak.maelkloud.com grafana.maelkloud.com prometheus.maelkloud.com; do
    resolved=$(dig +short "$domain" 2>/dev/null | head -1 || echo "")
    if [ -n "$resolved" ]; then
        if [ "$resolved" = "172.16.16.150" ]; then
            echo -e "${GREEN}✓${NC} $domain resolves to $resolved"
        else
            echo -e "${YELLOW}⚠${NC} $domain resolves to $resolved (expected 172.16.16.150)"
        fi
    else
        echo -e "${YELLOW}⚠${NC} $domain does not resolve (check /etc/hosts)"
    fi
done
echo ""

# Check 5: HTTP connectivity
echo "5. Testing HTTP connectivity to gateway..."
if curl -s -o /dev/null -w "%{http_code}" --max-time 5 -k https://172.16.16.150 -H "Host: grafana.maelkloud.com" 2>/dev/null | grep -q "200\|301\|302\|401\|403"; then
    echo -e "${GREEN}✓${NC} Gateway responds to HTTPS requests"
else
    echo -e "${RED}✗${NC} Gateway not responding to HTTPS"
    echo "   Testing HTTP..."
    if curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://172.16.16.150 -H "Host: grafana.maelkloud.com" 2>/dev/null | grep -q "200\|301\|302\|401\|403"; then
        echo -e "${GREEN}✓${NC} Gateway responds to HTTP (HTTPS may have cert issues)"
    else
        echo -e "${RED}✗${NC} Gateway not responding to HTTP either"
    fi
fi
echo ""

# Check 6: Kubernetes resources (if kubectl available)
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    echo "6. Checking Kubernetes resources..."
    
    # Check gateway service
    echo "   Gateway service:"
    if kubectl get svc main-gateway-istio -n istio-system &> /dev/null; then
        EXTERNAL_IP=$(kubectl get svc main-gateway-istio -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
        if [ "$EXTERNAL_IP" = "172.16.16.150" ]; then
            echo -e "     ${GREEN}✓${NC} Service has correct IP: $EXTERNAL_IP"
        elif [ "$EXTERNAL_IP" = "pending" ]; then
            echo -e "     ${YELLOW}⚠${NC} Service IP is pending"
        else
            echo -e "     ${YELLOW}⚠${NC} Service IP is $EXTERNAL_IP (expected 172.16.16.150)"
        fi
    else
        echo -e "     ${RED}✗${NC} Gateway service not found"
    fi
    
    # Check Tailscale service
    echo "   Tailscale service:"
    if kubectl get svc main-gateway-tailscale -n istio-system &> /dev/null; then
        echo -e "     ${GREEN}✓${NC} Tailscale service exists"
        kubectl get svc main-gateway-tailscale -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "     (IP pending)"
    else
        echo -e "     ${YELLOW}⚠${NC} Tailscale service not found (may need to apply manually)"
    fi
    
    # Check HTTPRoutes
    echo "   HTTPRoutes:"
    if kubectl get httproute keycloak-route -n keycloak &> /dev/null; then
        echo -e "     ${GREEN}✓${NC} keycloak-route exists"
    else
        echo -e "     ${RED}✗${NC} keycloak-route missing"
    fi
    if kubectl get httproute grafana-route -n observability &> /dev/null; then
        echo -e "     ${GREEN}✓${NC} grafana-route exists"
    else
        echo -e "     ${RED}✗${NC} grafana-route missing"
    fi
    if kubectl get httproute prometheus-route -n observability &> /dev/null; then
        echo -e "     ${GREEN}✓${NC} prometheus-route exists"
    else
        echo -e "     ${RED}✗${NC} prometheus-route missing"
    fi
    
    # Check Tailscale operator
    echo "   Tailscale operator:"
    if kubectl get pods -n tailscale 2>/dev/null | grep -q "operator.*Running"; then
        echo -e "     ${GREEN}✓${NC} Operator is running"
        kubectl get pods -n tailscale | grep operator
    elif kubectl get pods -n tailscale 2>/dev/null | grep -q operator; then
        echo -e "     ${YELLOW}⚠${NC} Operator pod exists but not running"
        kubectl get pods -n tailscale | grep operator
    else
        echo -e "     ${RED}✗${NC} Operator not found"
    fi
else
    echo "6. Skipping Kubernetes checks (kubectl not available or not connected)"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "If services are loading but never completing:"
echo "1. Verify /etc/hosts has correct entries"
echo "2. Check subnet route is approved in Tailscale admin"
echo "3. Try accessing via IP: curl -k https://172.16.16.150 -H 'Host: grafana.maelkloud.com'"
echo "4. Check browser console for errors (F12 → Console)"
echo "5. Verify certificates are valid: kubectl get certificates -A"

