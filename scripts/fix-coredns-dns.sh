#!/usr/bin/env bash
#
# Fix cluster DNS by making CoreDNS use reliable upstream resolvers (8.8.8.8, 8.8.4.4).
# Use this when pods get "server misbehaving" or cannot resolve external hostnames (e.g. github.com).
#
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
UPSTREAM_DNS="${UPSTREAM_DNS:-8.8.8.8 8.8.4.4}"

echo -e "${GREEN}[INFO]${NC} Patching CoreDNS to forward external DNS to: $UPSTREAM_DNS"

if ! kubectl cluster-info &>/dev/null; then
  echo -e "${YELLOW}[WARN]${NC} Cannot reach cluster. Ensure kubeconfig is set and cluster is up."
  exit 1
fi

# Get current Corefile and patch the forward directive if still using /etc/resolv.conf
# Default kubeadm uses: forward . /etc/resolv.conf
CM=$(kubectl get configmap coredns -n kube-system -o yaml)
if echo "$CM" | grep -q '/etc/resolv.conf'; then
  echo "$CM" | sed "s|forward \. /etc/resolv\.conf|forward . $UPSTREAM_DNS|" | kubectl apply -f -
fi
echo -e "${GREEN}[INFO]${NC} Restarting CoreDNS and Flux source-controller so pods use current DNS..."
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system --timeout=120s
kubectl rollout restart deployment source-controller -n flux-system
kubectl rollout status deployment source-controller -n flux-system --timeout=120s
echo -e "${GREEN}[INFO]${NC} Waiting for DNS to be ready..."
sleep 10

if command -v flux &>/dev/null; then
  echo -e "${GREEN}[INFO]${NC} Triggering Flux to reconcile GitRepository (retry clone)..."
  flux reconcile source git mkloudlab -n flux-system --timeout=2m || true
  echo -e "${GREEN}[INFO]${NC} Triggering Flux to reconcile all Kustomizations and HelmReleases..."
  for k in $(kubectl get kustomizations -n flux-system -o name 2>/dev/null | cut -d/ -f2); do flux reconcile kustomization "$k" -n flux-system --timeout=1m || true; done
  kubectl get helmreleases -A --no-headers 2>/dev/null | while read -r ns name rest; do flux reconcile helmrelease "$name" -n "$ns" --timeout=1m || true; done
fi

echo -e "${GREEN}[INFO]${NC} Done. Check sync: task flux:status-all"
