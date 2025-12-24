#!/bin/bash

# Script to copy kubeconfig from Kubernetes controller VM to local machine
# This script safely merges the new config with your existing ~/.kube/config

set -e

CONTROLLER_IP="172.16.16.100"
CONTROLLER_USER="root"
CONTROLLER_PASSWORD="kubeadmin"
KUBECONFIG_DIR="$HOME/.kube"
KUBECONFIG_DEFAULT="$KUBECONFIG_DIR/config"
KUBECONFIG_NEW="$KUBECONFIG_DIR/config.mkloudlab"

echo "🔐 Setting up kubeconfig for mkloudlab local access..."
echo "DEBUG: Removing the old context if it exists..."
# Remove the old context if it exists
kubectl config delete-context mkloudlab >/dev/null 2>&1 || true
kubectl config delete-cluster mkloudlab >/dev/null 2>&1 || true
kubectl config delete-user mkloudlab >/dev/null 2>&1 || true

# Create .kube directory in home if it doesn't exist
if [ ! -d "$KUBECONFIG_DIR" ]; then
    mkdir -p "$KUBECONFIG_DIR"
fi

# Check if controller is reachable
echo "Checking connectivity to controller ($CONTROLLER_IP)..."
MAX_RETRIES=5
RETRY_COUNT=0
CONNECTED=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if ping -c 1 "$CONTROLLER_IP" >/dev/null 2>&1; then
        CONNECTED=true
        break
    else
        echo "   Attempt $((RETRY_COUNT+1))/$MAX_RETRIES: Controller not reachable yet. Retrying in 5s..."
        sleep 5
        RETRY_COUNT=$((RETRY_COUNT+1))
    fi
done

if [ "$CONNECTED" = false ]; then
    echo "❌ Error: Cannot reach controller at $CONTROLLER_IP after $MAX_RETRIES attempts"
    echo "   Make sure the cluster is running: task vagrant:up"
    exit 1
fi

# Install sshpass if not available (for macOS with Homebrew)
if ! command -v sshpass &> /dev/null; then
    if command -v brew &> /dev/null; then
        echo "🍺 Installing sshpass via Homebrew..."
        brew install hudochenkov/sshpass/sshpass
    else
        echo "❌ Error: sshpass not available and Homebrew not installed."
        exit 1
    fi
fi

# Copy kubeconfig from controller VM to a temporary file
echo "📥 Downloading kubeconfig from controller..."
sshpass -p "$CONTROLLER_PASSWORD" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$CONTROLLER_USER@$CONTROLLER_IP:/etc/kubernetes/admin.conf" "$KUBECONFIG_NEW"

# Set permissions
chmod 600 "$KUBECONFIG_NEW"

# Modify the new kubeconfig (Context/User/Cluster renaming to avoid conflicts)
echo "🔄 Configuring context as 'mkloudlab'..."

# Create a temporary environment to modify ONLY the new config
export KUBECONFIG="$KUBECONFIG_NEW"

# Remove certificate-authority-data (we will use insecure-skip-verify in dev)
sed -i.bak2 '/certificate-authority-data:/d' "$KUBECONFIG_NEW"

# Add insecure-skip-tls-verify to the cluster config
# We match the server line (which now has the IP) to append the insecure flag
awk -v ip="$CONTROLLER_IP" '$0 ~ "server: https://" ip ":6443" { print; print "    insecure-skip-tls-verify: true"; next } 1' "$KUBECONFIG_NEW" > "${KUBECONFIG_NEW}.tmp" && mv "${KUBECONFIG_NEW}.tmp" "$KUBECONFIG_NEW"

# Clean up sed backups
rm -f "${KUBECONFIG_NEW}.bak" "${KUBECONFIG_NEW}.bak2" "${KUBECONFIG_NEW}.bak3"

# Rename context, user, and cluster to 'mkloudlab'
# Rename cluster and user using sed (kubectl config rename-cluster/user don't exist)
sed -i.bak4 's/name: kubernetes$/name: mkloudlab/' "$KUBECONFIG_NEW"
sed -i.bak5 's/cluster: kubernetes$/cluster: mkloudlab/' "$KUBECONFIG_NEW"
sed -i.bak6 's/user: kubernetes-admin$/user: mkloudlab/' "$KUBECONFIG_NEW"
sed -i.bak7 's/name: kubernetes-admin$/name: mkloudlab/' "$KUBECONFIG_NEW"

# Clean up backups
rm -f "${KUBECONFIG_NEW}.bak"*

# Rename context to 'mkloudlab'
kubectl config rename-context kubernetes-admin@kubernetes mkloudlab

# Now Merge with existing config
echo "twisted-merge: Merging with existing kubeconfig..."

# Backup existing config
if [ -f "$KUBECONFIG_DEFAULT" ]; then
    cp "$KUBECONFIG_DEFAULT" "${KUBECONFIG_DEFAULT}.bak"
    
    # Remove existing mkloudlab context if it exists to ensure we use the new one
    # We do this on the DEFAULT file using a temporary KUBECONFIG env
    (
        export KUBECONFIG="$KUBECONFIG_DEFAULT"
        if kubectl config get-contexts mkloudlab >/dev/null 2>&1; then
             echo "   Removing existing 'mkloudlab' context to prevent conflicts..."
             kubectl config delete-context mkloudlab >/dev/null 2>&1 || true
             kubectl config delete-cluster mkloudlab >/dev/null 2>&1 || true
             kubectl config delete-user mkloudlab >/dev/null 2>&1 || true
        fi
    )

    # Merge using KUBECONFIG env var
    # Put NEW first to ensure it takes precedence
    export KUBECONFIG="$KUBECONFIG_NEW:$KUBECONFIG_DEFAULT"
    kubectl config view --flatten > "${KUBECONFIG_DEFAULT}.merged"
    mv "${KUBECONFIG_DEFAULT}.merged" "$KUBECONFIG_DEFAULT"
    chmod 600 "$KUBECONFIG_DEFAULT"
    echo "✅ Kubeconfig merged."
else
    # No existing config, just move the new one
    mv "$KUBECONFIG_NEW" "$KUBECONFIG_DEFAULT"
    chmod 600 "$KUBECONFIG_DEFAULT"
    echo "✅ Created new ~/.kube/config"
fi

# Clean up temp file
rm -f "$KUBECONFIG_NEW"

echo ""
echo "🔄 Switching to context 'mkloudlab'..."
kubectl config use-context mkloudlab

echo ""
echo "🎉 Context 'mkloudlab' is ready and active!"
echo "   Verify with: kubectl cluster-info"
