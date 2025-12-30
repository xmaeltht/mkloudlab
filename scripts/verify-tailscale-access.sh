#!/bin/bash
# Verify Tailscale access to Kubernetes services
# Run this from your Mac after setting up Tailscale

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

METALLB_IP="172.16.16.150"
KCONTROLLER_IP="172.16.16.100"
SERVICES=(
  "keycloak.maelkloud.com"
  "grafana.maelkloud.com"
  "prometheus.maelkloud.com"
  "loki.maelkloud.com"
  "tempo.maelkloud.com"
  "alloy.maelkloud.com"
)

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Tailscale Access Verification for mkloudlab${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to print status
print_status() {
  local status=$1
  local message=$2
  if [ "$status" == "ok" ]; then
    echo -e "${GREEN}✓${NC} $message"
  elif [ "$status" == "warn" ]; then
    echo -e "${YELLOW}⚠${NC} $message"
  elif [ "$status" == "fail" ]; then
    echo -e "${RED}✗${NC} $message"
  else
    echo -e "${BLUE}ℹ${NC} $message"
  fi
}

# Check 1: Tailscale installed on local machine
echo -e "\n${YELLOW}[1/8]${NC} Checking local Tailscale installation..."
if command -v tailscale &> /dev/null; then
  print_status "ok" "Tailscale CLI found"
  TAILSCALE_STATUS=$(tailscale status --json 2>/dev/null || echo "{}")
  if echo "$TAILSCALE_STATUS" | grep -q "BackendState.*Running"; then
    print_status "ok" "Tailscale is running"
  else
    print_status "fail" "Tailscale is not running. Run: sudo tailscale up"
    exit 1
  fi
else
  print_status "warn" "Tailscale not found on local machine"
  print_status "info" "Install from: https://tailscale.com/download"
  echo ""
  echo "You can still proceed if Tailscale is installed on another device"
  read -p "Continue? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check 2: Subnet route connectivity
echo -e "\n${YELLOW}[2/8]${NC} Checking subnet route connectivity..."
if ping -c 1 -W 2 "$KCONTROLLER_IP" &> /dev/null; then
  print_status "ok" "Can reach kcontroller ($KCONTROLLER_IP)"
  SUBNET_ROUTING=true
else
  print_status "fail" "Cannot reach kcontroller ($KCONTROLLER_IP)"
  print_status "info" "Subnet routing may not be configured or approved"
  SUBNET_ROUTING=false
fi

# Check 3: MetalLB gateway reachability
echo -e "\n${YELLOW}[3/8]${NC} Checking MetalLB gateway..."
if [ "$SUBNET_ROUTING" == "true" ]; then
  if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://$METALLB_IP" | grep -q ".*"; then
    print_status "ok" "MetalLB gateway ($METALLB_IP) is reachable"
    METALLB_REACHABLE=true
  else
    print_status "warn" "MetalLB gateway reachable but no response"
    METALLB_REACHABLE=true
  fi
else
  print_status "warn" "Skipping (subnet routing not available)"
  METALLB_REACHABLE=false
fi

# Check 4: Service HTTPS endpoints (with SNI)
echo -e "\n${YELLOW}[4/8]${NC} Checking service HTTPS endpoints..."
if [ "$METALLB_REACHABLE" == "true" ]; then
  SUCCESS_COUNT=0
  for service in "${SERVICES[@]}"; do
    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 2 \
      -H "Host: $service" "https://$METALLB_IP" || echo "000")

    if [ "$HTTP_CODE" != "000" ] && [ "$HTTP_CODE" != "503" ]; then
      print_status "ok" "$service → HTTP $HTTP_CODE"
      ((SUCCESS_COUNT++))
    else
      print_status "fail" "$service → HTTP $HTTP_CODE (Service may be down)"
    fi
  done

  if [ $SUCCESS_COUNT -eq ${#SERVICES[@]} ]; then
    print_status "ok" "All services responding"
  else
    print_status "warn" "$SUCCESS_COUNT/${#SERVICES[@]} services responding"
  fi
else
  print_status "warn" "Skipping (MetalLB not reachable)"
fi

# Check 5: Tailscale Kubernetes operator
echo -e "\n${YELLOW}[5/8]${NC} Checking Tailscale Kubernetes operator..."
if kubectl get namespace tailscale &> /dev/null; then
  print_status "ok" "Tailscale namespace exists"

  OPERATOR_POD=$(kubectl get pods -n tailscale -l app=tailscale-operator -o name 2>/dev/null | head -1)
  if [ -n "$OPERATOR_POD" ]; then
    OPERATOR_STATUS=$(kubectl get "$OPERATOR_POD" -n tailscale -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$OPERATOR_STATUS" == "Running" ]; then
      print_status "ok" "Operator pod is running"
    else
      print_status "warn" "Operator pod status: $OPERATOR_STATUS"
    fi
  else
    print_status "warn" "Operator pod not found (may not be deployed yet)"
  fi

  if kubectl get secret operator-oauth -n tailscale &> /dev/null; then
    print_status "ok" "OAuth secret configured"
  else
    print_status "warn" "OAuth secret not found"
    print_status "info" "Create with: kubectl create secret generic operator-oauth -n tailscale ..."
  fi
else
  print_status "info" "Tailscale namespace not found (operator not deployed)"
fi

# Check 6: Tailscale LoadBalancer service
echo -e "\n${YELLOW}[6/8]${NC} Checking Tailscale LoadBalancer services..."
TS_SVCS=$(kubectl get svc -A --field-selector spec.type=LoadBalancer -o json 2>/dev/null | \
  jq -r '.items[] | select(.spec.loadBalancerClass == "tailscale") | .metadata.namespace + "/" + .metadata.name' || echo "")

if [ -n "$TS_SVCS" ]; then
  echo "$TS_SVCS" | while read -r svc; do
    NAMESPACE=$(echo "$svc" | cut -d'/' -f1)
    NAME=$(echo "$svc" | cut -d'/' -f2)
    TS_HOSTNAME=$(kubectl get svc -n "$NAMESPACE" "$NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

    if [ -n "$TS_HOSTNAME" ]; then
      print_status "ok" "$NAMESPACE/$NAME → $TS_HOSTNAME"
    else
      print_status "warn" "$NAMESPACE/$NAME (Tailscale hostname not assigned yet)"
    fi
  done
else
  print_status "info" "No Tailscale LoadBalancer services found"
fi

# Check 7: DNS resolution (if using /etc/hosts)
echo -e "\n${YELLOW}[7/8]${NC} Checking DNS configuration..."
if grep -q "$METALLB_IP" /etc/hosts 2>/dev/null; then
  print_status "ok" "/etc/hosts configured for services"
  HOSTS_CONFIGURED=true
else
  print_status "info" "/etc/hosts not configured (optional)"
  HOSTS_CONFIGURED=false
fi

# Check 8: End-to-end service test
echo -e "\n${YELLOW}[8/8]${NC} Running end-to-end service test..."
if [ "$METALLB_REACHABLE" == "true" ]; then
  # Test Keycloak as representative service
  TEST_URL="https://keycloak.maelkloud.com"
  if [ "$HOSTS_CONFIGURED" == "true" ]; then
    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TEST_URL" || echo "000")
  else
    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
      -H "Host: keycloak.maelkloud.com" "https://$METALLB_IP" || echo "000")
  fi

  if [ "$HTTP_CODE" != "000" ] && [ "$HTTP_CODE" != "503" ]; then
    print_status "ok" "End-to-end test successful (HTTP $HTTP_CODE)"
  else
    print_status "fail" "End-to-end test failed (HTTP $HTTP_CODE)"
  fi
else
  print_status "warn" "Skipping (prerequisites not met)"
fi

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$SUBNET_ROUTING" == "true" ] && [ "$METALLB_REACHABLE" == "true" ]; then
  echo -e "${GREEN}✓ Access Method: Subnet Routing${NC}"
  echo ""
  echo "You can access services using:"
  if [ "$HOSTS_CONFIGURED" == "true" ]; then
    echo "  • Direct URLs: https://keycloak.maelkloud.com"
  else
    echo "  • With Host header: curl -H 'Host: keycloak.maelkloud.com' https://$METALLB_IP"
    echo "  • Or add to /etc/hosts: echo '$METALLB_IP  keycloak.maelkloud.com' | sudo tee -a /etc/hosts"
  fi
elif kubectl get svc -A --field-selector spec.type=LoadBalancer -o json 2>/dev/null | \
  jq -e '.items[] | select(.spec.loadBalancerClass == "tailscale")' &> /dev/null; then
  echo -e "${GREEN}✓ Access Method: Tailscale LoadBalancer${NC}"
  echo ""
  echo "Get Tailscale hostnames:"
  echo "  kubectl get svc -n istio-system main-gateway-tailscale"
else
  echo -e "${YELLOW}⚠ No access method configured${NC}"
  echo ""
  echo "Setup options:"
  echo "  1. Configure subnet routing (recommended for homelab)"
  echo "     See: docs/TAILSCALE_SETUP.md"
  echo ""
  echo "  2. Deploy Tailscale operator"
  echo "     kubectl apply -f platform/networking/tailscale/"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Exit code
if [ "$SUBNET_ROUTING" == "true" ] || kubectl get svc -A --field-selector spec.type=LoadBalancer -o json 2>/dev/null | \
  jq -e '.items[] | select(.spec.loadBalancerClass == "tailscale")' &> /dev/null; then
  exit 0
else
  exit 1
fi
