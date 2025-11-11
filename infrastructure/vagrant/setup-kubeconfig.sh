#!/bin/bash

# Script to copy kubeconfig from Kubernetes controller VM to local machine
# This script should be run from your local machine after the cluster is set up

set -e

CONTROLLER_IP="172.16.16.100"
CONTROLLER_USER="root"
CONTROLLER_PASSWORD="kubeadmin"
KUBECONFIG_DEST="$HOME/.kube/config"

echo "Setting up kubeconfig for local access..."

# Create .kube directory in home if it doesn't exist
if [ ! -d "$HOME/.kube" ]; then
    echo "Creating .kube directory..."
    mkdir -p "$HOME/.kube"
else
    echo ".kube directory already exists"
fi

# Check if controller is reachable
echo "Checking connectivity to controller ($CONTROLLER_IP)..."
if ! ping -c 1 "$CONTROLLER_IP" >/dev/null 2>&1; then
    echo "Error: Cannot reach controller at $CONTROLLER_IP"
    echo "Make sure the cluster is running: vagrant status"
    exit 1
fi

# Install sshpass if not available (for macOS with Homebrew)
if ! command -v sshpass &> /dev/null; then
    echo "sshpass not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install hudochenkov/sshpass/sshpass
    else
        echo "Error: sshpass not available and Homebrew not installed."
        echo "Please install sshpass manually or use the manual method:"
        echo "  scp $CONTROLLER_USER@$CONTROLLER_IP:/etc/kubernetes/admin.conf $KUBECONFIG_DEST"
        exit 1
    fi
fi

# Copy kubeconfig from controller VM to local machine
echo "Copying kubeconfig from controller..."
sshpass -p "$CONTROLLER_PASSWORD" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$CONTROLLER_USER@$CONTROLLER_IP:/etc/kubernetes/admin.conf" "$KUBECONFIG_DEST"

# Set proper permissions
chmod 600 "$KUBECONFIG_DEST"

echo "✅ Kubeconfig copied to $KUBECONFIG_DEST"
echo ""
echo "You can now access your Kubernetes cluster using:"
echo "  kubectl get nodes"
echo "  kubectl get pods --all-namespaces"
echo ""
echo "Cluster details:"
echo "  Master node: kcontroller ($CONTROLLER_IP)"
echo "  Worker nodes: knode1, knode2, knode3 (172.16.16.101-103)"
