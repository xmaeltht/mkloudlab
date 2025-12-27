#!/bin/bash
# Script to verify domain-based access setup for all services

set -e

echo "🔍 Verifying Domain Access Setup"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

echo "1. Checking Main Gateway..."
echo "----------------------------"
GATEWAY_STATUS=$(kubectl get gateway main-gateway -n istio-system -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "NotFound")
if [ "$GATEWAY_STATUS" = "True" ]; then
    echo -e "${GREEN}✅ Main gateway is programmed${NC}"
else
    echo -e "${RED}❌ Main gateway is not programmed (status: $GATEWAY_STATUS)${NC}"
fi

echo ""
echo "2. Checking LoadBalancer Service..."
echo "------------------------------------"
LB_IP=$(kubectl get svc main-gateway-istio -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
SERVICE_TYPE=$(kubectl get svc main-gateway-istio -n istio-system -o jsonpath='{.spec.type}' 2>/dev/null || echo "NotFound")

if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
    echo -e "${GREEN}✅ Main gateway service is LoadBalancer${NC}"
    if [ -n "$LB_IP" ]; then
        echo -e "${GREEN}✅ LoadBalancer IP: $LB_IP${NC}"
    else
        echo -e "${YELLOW}⚠️  LoadBalancer IP not assigned yet (MetalLB may still be provisioning)${NC}"
    fi
else
    echo -e "${RED}❌ Main gateway service type is $SERVICE_TYPE (expected LoadBalancer)${NC}"
fi

echo ""
echo "3. Checking HTTPRoutes..."
echo "--------------------------"
SERVICES=("keycloak:keycloak" "sonarqube:sonarqube" "grafana:observability" "prometheus:observability" "loki:observability" "tempo:observability" "alloy:observability")

ALL_ROUTES_OK=true
for SERVICE_INFO in "${SERVICES[@]}"; do
    SERVICE_NAME=$(echo $SERVICE_INFO | cut -d: -f1)
    NAMESPACE=$(echo $SERVICE_INFO | cut -d: -f2)
    ROUTE_NAME="${SERVICE_NAME}-route"
    
    ROUTE_EXISTS=$(kubectl get httproute $ROUTE_NAME -n $NAMESPACE -o name 2>/dev/null || echo "")
    if [ -n "$ROUTE_EXISTS" ]; then
        PARENT_REF=$(kubectl get httproute $ROUTE_NAME -n $NAMESPACE -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null || echo "")
        if [ "$PARENT_REF" = "main-gateway" ]; then
            echo -e "${GREEN}✅ $ROUTE_NAME exists and references main-gateway${NC}"
        else
            echo -e "${RED}❌ $ROUTE_NAME exists but references $PARENT_REF (expected main-gateway)${NC}"
            ALL_ROUTES_OK=false
        fi
    else
        echo -e "${RED}❌ $ROUTE_NAME not found${NC}"
        ALL_ROUTES_OK=false
    fi
done

if [ "$ALL_ROUTES_OK" = true ]; then
    echo -e "${GREEN}✅ All HTTPRoutes are configured correctly${NC}"
else
    echo -e "${RED}❌ Some HTTPRoutes are missing or misconfigured${NC}"
fi

echo ""
echo "4. Checking Certificates..."
echo "----------------------------"
CERT_NAMESPACES=("keycloak:keycloak-cert" "sonarqube:sonarqube-cert" "observability:grafana-cert" "observability:prometheus-cert" "observability:loki-cert" "observability:tempo-cert" "observability:alloy-cert")

ALL_CERTS_OK=true
for CERT_INFO in "${CERT_NAMESPACES[@]}"; do
    NAMESPACE=$(echo $CERT_INFO | cut -d: -f1)
    CERT_NAME=$(echo $CERT_INFO | cut -d: -f2)
    
    CERT_READY=$(kubectl get certificate $CERT_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")
    if [ "$CERT_READY" = "True" ]; then
        echo -e "${GREEN}✅ $CERT_NAME in $NAMESPACE is ready${NC}"
    else
        echo -e "${YELLOW}⚠️  $CERT_NAME in $NAMESPACE is not ready (status: $CERT_READY)${NC}"
        ALL_CERTS_OK=false
    fi
done

if [ "$ALL_CERTS_OK" = true ]; then
    echo -e "${GREEN}✅ All certificates are ready${NC}"
else
    echo -e "${YELLOW}⚠️  Some certificates are not ready yet (this is normal if they're being issued)${NC}"
fi

echo ""
echo "5. Checking External-DNS..."
echo "----------------------------"
EXTERNAL_DNS_POD=$(kubectl get pods -n networking -l app.kubernetes.io/name=external-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$EXTERNAL_DNS_POD" ]; then
    EXTERNAL_DNS_READY=$(kubectl get pod $EXTERNAL_DNS_POD -n networking -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    if [ "$EXTERNAL_DNS_READY" = "True" ]; then
        echo -e "${GREEN}✅ External-DNS pod is running${NC}"
        echo "   Recent logs:"
        kubectl logs -n networking $EXTERNAL_DNS_POD --tail=5 2>/dev/null | sed 's/^/   /' || echo "   (unable to fetch logs)"
    else
        echo -e "${YELLOW}⚠️  External-DNS pod is not ready${NC}"
    fi
else
    echo -e "${RED}❌ External-DNS pod not found${NC}"
fi

echo ""
echo "6. Checking MetalLB..."
echo "-----------------------"
METALLB_CONTROLLER=$(kubectl get pods -n networking -l app.kubernetes.io/name=metallb,app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$METALLB_CONTROLLER" ]; then
    echo -e "${GREEN}✅ MetalLB controller is running${NC}"
else
    echo -e "${RED}❌ MetalLB controller not found${NC}"
fi

echo ""
echo "7. DNS Resolution Test..."
echo "-------------------------"
if [ -n "$LB_IP" ]; then
    echo "Testing DNS resolution for services..."
    DOMAINS=("keycloak.maelkloud.com" "sonarqube.maelkloud.com" "grafana.maelkloud.com" "prometheus.maelkloud.com" "loki.maelkloud.com" "tempo.maelkloud.com" "alloy.maelkloud.com")
    
    for DOMAIN in "${DOMAINS[@]}"; do
        if command -v dig &> /dev/null; then
            DNS_IP=$(dig +short $DOMAIN @8.8.8.8 2>/dev/null | head -1 || echo "")
            if [ -n "$DNS_IP" ]; then
                if [ "$DNS_IP" = "$LB_IP" ]; then
                    echo -e "${GREEN}✅ $DOMAIN resolves to $DNS_IP${NC}"
                else
                    echo -e "${YELLOW}⚠️  $DOMAIN resolves to $DNS_IP (expected $LB_IP)${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  $DOMAIN does not resolve yet (DNS propagation may take time)${NC}"
            fi
        elif command -v nslookup &> /dev/null; then
            DNS_IP=$(nslookup $DOMAIN 8.8.8.8 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "")
            if [ -n "$DNS_IP" ]; then
                if [ "$DNS_IP" = "$LB_IP" ]; then
                    echo -e "${GREEN}✅ $DOMAIN resolves to $DNS_IP${NC}"
                else
                    echo -e "${YELLOW}⚠️  $DOMAIN resolves to $DNS_IP (expected $LB_IP)${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  $DOMAIN does not resolve yet (DNS propagation may take time)${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  dig/nslookup not available, skipping DNS resolution test${NC}"
            break
        fi
    done
else
    echo -e "${YELLOW}⚠️  Skipping DNS test (no LoadBalancer IP available)${NC}"
fi

echo ""
echo "=================================="
echo "✅ Verification complete!"
echo ""
echo "Next steps:"
echo "1. If LoadBalancer IP is assigned, check Cloudflare DNS records"
echo "2. Wait for external-dns to create/update DNS records (may take a few minutes)"
echo "3. Test HTTPS access: curl -I https://keycloak.maelkloud.com"
echo ""

