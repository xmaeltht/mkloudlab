#!/bin/bash
# Setup Tailscale on all Vagrant VMs
# Run this from your host machine (macOS)

set -euo pipefail

VAGRANT_DIR="/Users/mael/workspace/kubernetes/mkloudlab/infrastructure/vagrant"
VMS=("kcontroller" "knode1" "knode2" "knode3")

echo "=== Setting up Tailscale on Vagrant VMs ==="
echo ""

# Change to vagrant directory
cd "$VAGRANT_DIR"

# Copy installation script to VMs
echo "📋 Copying installation script to VMs..."
for vm in "${VMS[@]}"; do
  echo "  → $vm"
  vagrant upload install-tailscale.sh /tmp/install-tailscale.sh "$vm"
done

echo ""
echo "🔧 Installing Tailscale on each VM..."
for vm in "${VMS[@]}"; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  VM: $vm"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  vagrant ssh "$vm" -c "chmod +x /tmp/install-tailscale.sh && /tmp/install-tailscale.sh"
done

echo ""
echo "✅ Tailscale installation complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NEXT STEPS - Authenticate and Configure Subnet Routing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "You need to start Tailscale on each VM and authenticate."
echo "We'll configure kcontroller as the subnet router for the cluster network."
echo ""
echo "Run these commands:"
echo ""
echo "1. Start Tailscale on kcontroller (as subnet router):"
echo "   cd $VAGRANT_DIR"
echo "   vagrant ssh kcontroller -c 'sudo tailscale up --advertise-routes=172.16.16.0/24 --accept-routes --hostname=mkloud-kcontroller'"
echo ""
echo "2. Visit the auth URL shown above and authenticate"
echo ""
echo "3. In Tailscale admin console (https://login.tailscale.com/admin/machines):"
echo "   - Find 'mkloud-kcontroller'"
echo "   - Click '...' → Edit route settings"
echo "   - Enable subnet route for 172.16.16.0/24"
echo ""
echo "4. Optional - Start Tailscale on worker nodes (for management):"
echo "   vagrant ssh knode1 -c 'sudo tailscale up --accept-routes --hostname=mkloud-knode1'"
echo "   vagrant ssh knode2 -c 'sudo tailscale up --accept-routes --hostname=mkloud-knode2'"
echo "   vagrant ssh knode3 -c 'sudo tailscale up --accept-routes --hostname=mkloud-knode3'"
echo ""
echo "5. Test connectivity from your machine:"
echo "   ping 172.16.16.100  # Should reach kcontroller via Tailscale"
echo "   curl http://172.16.16.150  # Should reach your services via MetalLB"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
