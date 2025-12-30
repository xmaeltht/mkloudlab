#!/bin/bash
# Quick test script for service access via Tailscale

set -euo pipefail

GATEWAY_IP="172.16.16.150"

echo "=== Testing Service Access ==="
echo ""

echo "1. Testing HTTP (should redirect to HTTPS):"
for service in grafana prometheus keycloak; do
    echo -n "  $service.maelkloud.com: "
    if curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$GATEWAY_IP -H "Host: $service.maelkloud.com" | grep -q "30[0-9]"; then
        echo "✓ Redirects to HTTPS"
    else
        echo "✗ Failed"
    fi
done

echo ""
echo "2. Testing HTTPS (may fail with curl but work in browser):"
for service in grafana prometheus keycloak; do
    echo -n "  $service.maelkloud.com: "
    if curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 https://$GATEWAY_IP -H "Host: $service.maelkloud.com" 2>/dev/null | grep -q "[0-9]"; then
        echo "✓ Responds"
    else
        echo "⚠ Connection issue (try browser)"
    fi
done

echo ""
echo "3. Access URLs:"
echo "   HTTP (will redirect):"
for service in grafana prometheus keycloak; do
    echo "     http://$service.maelkloud.com"
done

echo ""
echo "   HTTPS (direct):"
for service in grafana prometheus keycloak; do
    echo "     https://$service.maelkloud.com"
done

echo ""
echo "=== Recommendation ==="
echo "Try accessing services in your browser:"
echo "  1. Start with HTTP: http://grafana.maelkloud.com"
echo "  2. Browser will auto-redirect to HTTPS"
echo "  3. Accept the certificate warning if needed"
echo ""
echo "If pages load but don't complete, check browser console (F12) for errors"
