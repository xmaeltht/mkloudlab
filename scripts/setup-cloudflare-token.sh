#!/bin/bash

# Cloudflare Token Setup Script
# This script helps you set up your Cloudflare API token for automated certificate management

set -e

echo "🔐 Cloudflare API Token Setup"
echo "=============================="
echo ""

# Check if token is already set
if [ ! -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "✅ CLOUDFLARE_API_TOKEN is already set"
    echo "   Token: ${CLOUDFLARE_API_TOKEN:0:10}..."
    echo ""
    echo "To use it for prerequisites installation:"
    echo "   task install:prerequisites"
    echo ""
    exit 0
fi

echo "This script will help you set up your Cloudflare API token for automated"
echo "TLS certificate management using DNS-01 challenges."
echo ""

echo "📋 Prerequisites:"
echo "   1. Cloudflare account with DNS management access"
echo "   2. Domain managed by Cloudflare"
echo "   3. API token with Zone:Read and DNS:Edit permissions"
echo ""

echo "🔗 Create API Token:"
echo "   1. Go to: https://dash.cloudflare.com/profile/api-tokens"
echo "   2. Click 'Create Token'"
echo "   3. Use 'Custom token' template"
echo "   4. Set permissions:"
echo "      - Zone:Zone:Read"
echo "      - Zone:DNS:Edit"
echo "   5. Set Zone Resources: Include - Specific zone - your-domain.com"
echo "   6. Copy the generated token"
echo ""

read -p "Enter your Cloudflare API token: " -s CLOUDFLARE_TOKEN
echo ""

if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo "❌ No token provided. Exiting."
    exit 1
fi

echo ""
echo "🔧 Setting up environment..."

# Add to current shell
export CLOUDFLARE_API_TOKEN="$CLOUDFLARE_TOKEN"

echo "⚠️  SECURITY ALERT: This script no longer saves the token to your shell profile."
echo "   This is to prevent storing secrets in plaintext on your disk."
echo ""
echo "   Please export the token for your current session:"
echo "   export CLOUDFLARE_API_TOKEN=\"$CLOUDFLARE_TOKEN\""

echo ""
echo "✅ Cloudflare API Token configured!"
echo ""
echo "🚀 Next steps:"
echo "   1. Run prerequisites installation:"
echo "      task install:prerequisites"
echo ""
echo "   2. Verify ClusterIssuers:"
echo "      kubectl get clusterissuer"
echo ""
echo "   3. Check Cloudflare secret:"
echo "      kubectl get secret cloudflare-api-token-secret -n cert-manager"
echo ""

# Test the token (optional)
echo "🧪 Testing token (optional)..."
if command -v curl >/dev/null 2>&1; then
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" | \
        jq -r '.result[0].id' 2>/dev/null || echo "")
    
    if [ ! -z "$ZONE_ID" ] && [ "$ZONE_ID" != "null" ]; then
        echo "✅ Token is valid and working"
        echo "   Zone ID: $ZONE_ID"
    else
        echo "⚠️  Could not verify token (jq not installed or API error)"
    fi
else
    echo "⚠️  curl not available for token testing"
fi

echo ""
echo "🎯 Your applications will now automatically get TLS certificates!"
echo "   All certificates will be managed by cert-manager using Cloudflare DNS-01 challenges."
