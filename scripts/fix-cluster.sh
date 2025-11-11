#!/bin/bash
# Quick fix script for cluster issues

set -e

echo "🔧 Fixing Cluster Issues..."

# 1. Delete old Keycloak resources
echo "1. Cleaning up old Keycloak resources..."
kubectl delete statefulset keycloak -n keycloak --ignore-not-found=true
kubectl delete statefulset keycloak-postgresql -n keycloak --ignore-not-found=true

# 2. Keycloak is now managed by Flux - check Flux status
echo "2. Keycloak is managed by Flux. Check status with: task flux:status"

# 3. Fix Loki - disable for now or use simpler config
echo "3. Disabling Loki temporarily (has persistent storage issues)..."
kubectl scale statefulset loki-stack --replicas=0 -n logging --ignore-not-found=true

# 4. Check Kyverno CRDs and restart if needed
echo "4. Checking Kyverno..."
if ! kubectl get crd clusterpolicies.kyverno.io &>/dev/null; then
  echo "   Installing Kyverno CRDs..."
  kubectl apply -f https://raw.githubusercontent.com/kyverno/kyverno/v1.12.0/config/crds/kyverno.io_clusterpolicies.yaml
  kubectl apply -f https://raw.githubusercontent.com/kyverno/kyverno/v1.12.0/config/crds/kyverno.io_policies.yaml
fi

# 5. Restart failed pods
echo "5. Restarting failed pods..."
kubectl delete pods --field-selector=status.phase=Failed -A --ignore-not-found=true

echo "✅ Fixes applied! Waiting for pods to stabilize..."
sleep 20

echo "📊 Current Status:"
kubectl get pods -A | grep -vE "Running|Completed" || echo "All pods are healthy!"

echo ""
echo "🎯 Next Steps:"
echo "1. Commit the local changes to Git for proper GitOps workflow"
echo "2. Run: task status"
echo "3. Run: task health"
echo "4. For Loki: Consider using a different logging solution or fix PVC permissions"
