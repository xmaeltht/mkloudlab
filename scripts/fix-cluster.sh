#!/bin/bash
# Quick fix script for cluster issues

set -e

echo "🔧 Fixing Cluster Issues..."

# 1. Delete old Keycloak resources
echo "1. Cleaning up old Keycloak resources..."
kubectl delete statefulset keycloak -n keycloak --ignore-not-found=true
kubectl delete statefulset keycloak-postgresql -n keycloak --ignore-not-found=true

# 2. Update Keycloak chart version to one that works
echo "2. Updating Keycloak to working version..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: keycloak
    targetRevision: 24.0.0
    helm:
      values: |
        auth:
          adminUser: admin
          adminPassword: Keycloak123!
        ingress:
          enabled: false
        production: true
        proxy: edge
        postgresql:
          enabled: true
          auth:
            postgresPassword: Keycloak123!
            password: Keycloak123!
        persistence:
          enabled: true
          size: 8Gi
        service:
          ports:
            http: 8080
            https: 8443
        extraEnvVars:
          - name: KC_HTTP_ENABLED
            value: "true"
          - name: KC_HTTP_PORT
            value: "8080"
          - name: KC_HOSTNAME
            value: keycloak.maelkloud.com
          - name: KC_PROXY
            value: edge
          - name: KC_HOSTNAME_STRICT
            value: "false"
  destination:
    server: https://kubernetes.default.svc
    namespace: keycloak
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

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
