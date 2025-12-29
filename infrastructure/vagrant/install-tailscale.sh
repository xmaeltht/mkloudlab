#!/bin/bash
# Install Tailscale on Ubuntu 24.04
# This script should be run on each Vagrant VM
#
# ⚠️ DEPRECATED - NOT RECOMMENDED ⚠️
#
# This script is no longer recommended. Instead, use the Tailscale Kubernetes Operator
# which provides subnet routing without requiring Tailscale on each VM.
#
# See: platform/networking/tailscale/README.md for the recommended approach.
#
# The operator approach:
# - Simpler management (one deployment vs per-VM setup)
# - Automatic HA and failover
# - Better integration with Kubernetes
# - No manual authentication per VM
#
# Tailscale has been disabled on all VMs in favor of the operator.
# This script is kept for reference only.
#
# If you still want to proceed with VM-level installation (not recommended), continue below.

set -euo pipefail

echo "=== Installing Tailscale on $(hostname) ==="

# Add Tailscale's package signing key and repository
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# Add repository with signed-by
echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu noble main" | sudo tee /etc/apt/sources.list.d/tailscale.list

# Install Tailscale
sudo apt-get update
sudo apt-get install -y tailscale

# Enable IP forwarding (required for subnet routing)
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "✅ Tailscale installed successfully on $(hostname)"
echo ""
echo "Next steps:"
echo "  1. Run: sudo tailscale up --advertise-routes=172.16.16.0/24 --accept-routes"
echo "  2. Visit the URL to authenticate"
echo "  3. In Tailscale admin console, approve the subnet routes"
echo ""
