#!/bin/bash
# Script to patch existing Istio Gateway API LoadBalancer services to ClusterIP
# This is a one-time migration script. The Kyverno policy will handle future services.

set -e

echo "🔧 Patching Istio Gateway API LoadBalancer services to ClusterIP..."

# Get all services with the gateway.istio.io/managed label that are LoadBalancer type
SERVICES=$(kubectl get svc -A -l gateway.istio.io/managed=istio.io-gateway-controller -o json | \
  jq -r '.items[] | select(.spec.type == "LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name)"')

if [ -z "$SERVICES" ]; then
  echo "✅ No LoadBalancer services found for Istio Gateway API"
  exit 0
fi

echo "Found LoadBalancer services to patch:"
echo "$SERVICES"
echo ""

# Patch each service
for SERVICE in $SERVICES; do
  NAMESPACE=$(echo $SERVICE | cut -d'/' -f1)
  NAME=$(echo $SERVICE | cut -d'/' -f2)
  
  echo "Patching $SERVICE..."
  kubectl patch svc "$NAME" -n "$NAMESPACE" -p '{"spec":{"type":"ClusterIP","externalIPs":null}}' --type=merge
  
  # Verify the patch
  CURRENT_TYPE=$(kubectl get svc "$NAME" -n "$NAMESPACE" -o jsonpath='{.spec.type}')
  if [ "$CURRENT_TYPE" = "ClusterIP" ]; then
    echo "✅ Successfully patched $SERVICE to ClusterIP"
  else
    echo "❌ Failed to patch $SERVICE (current type: $CURRENT_TYPE)"
    exit 1
  fi
done

echo ""
echo "✅ All Gateway API services have been patched to ClusterIP"
echo ""
echo "Note: The Kyverno policy 'gateway-service-clusterip' will automatically"
echo "      convert any future LoadBalancer services created by Istio Gateway API."

