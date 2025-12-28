#!/bin/bash
# Script to apply updated gateway configurations that point HTTPRoutes to main-gateway

set -e

echo "🔧 Applying Updated Gateway Configurations"
echo "==========================================="
echo ""
echo "This script will update all HTTPRoutes to point to main-gateway"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# List of gateway files to apply
GATEWAY_FILES=(
    "platform/identity/keycloak/gateway.yaml"
    "platform/devtools/sonarqube/gateway.yaml"
    "platform/observability/grafana/gateway.yaml"
    "platform/observability/prometheus/gateway.yaml"
    "platform/observability/loki/gateway.yaml"
    "platform/observability/tempo/gateway.yaml"
    "platform/observability/alloy/gateway.yaml"
)

echo "Applying gateway configurations..."
echo ""

for FILE in "${GATEWAY_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        echo -n "Applying $FILE... "
        if kubectl apply -f "$FILE" > /dev/null 2>&1; then
            echo -e "${GREEN}✅${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  $FILE not found, skipping${NC}"
    fi
done

echo ""
echo "Verifying HTTPRoutes..."
echo ""

# Verify HTTPRoutes point to main-gateway
SERVICES=(
    "keycloak:keycloak"
    "sonarqube:sonarqube"
    "grafana:observability"
    "prometheus:observability"
    "loki:observability"
    "tempo:observability"
    "alloy:observability"
)

ALL_OK=true
for SERVICE_INFO in "${SERVICES[@]}"; do
    SERVICE_NAME=$(echo $SERVICE_INFO | cut -d: -f1)
    NAMESPACE=$(echo $SERVICE_INFO | cut -d: -f2)
    ROUTE_NAME="${SERVICE_NAME}-route"
    
    PARENT_REF=$(kubectl get httproute $ROUTE_NAME -n $NAMESPACE -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null || echo "")
    PARENT_NS=$(kubectl get httproute $ROUTE_NAME -n $NAMESPACE -o jsonpath='{.spec.parentRefs[0].namespace}' 2>/dev/null || echo "")
    
    if [ "$PARENT_REF" = "main-gateway" ] && [ "$PARENT_NS" = "istio-system" ]; then
        echo -e "${GREEN}✅ $ROUTE_NAME → main-gateway (istio-system)${NC}"
    else
        echo -e "${RED}❌ $ROUTE_NAME → $PARENT_REF ($PARENT_NS)${NC}"
        ALL_OK=false
    fi
done

echo ""
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}✅ All HTTPRoutes are correctly configured!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Wait for DNS records to update (or manually update in Cloudflare)"
    echo "2. Run verification: ./scripts/verify-domain-access.sh"
    echo "3. Test access: curl -I https://keycloak.maelkloud.com"
else
    echo -e "${RED}❌ Some HTTPRoutes are not correctly configured${NC}"
    echo "Please check the output above and re-run this script if needed"
    exit 1
fi

