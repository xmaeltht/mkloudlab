#!/bin/bash

# Prerequisites Installation Script
# This script installs Gateway API, local-path storage, metrics-server, and cert-manager BEFORE Flux
# Note: Istio is now managed by Flux and will be installed via HelmRelease (platform/flux/apps/istio.yaml)

set -e

echo "🚀 Installing Prerequisites for GitOps Deployment"
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
print_status "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "✅ Cluster connectivity confirmed"

# Step 1: Install Gateway API CRDs
print_status "Step 1: Installing Gateway API CRDs..."
if kubectl get crd gatewayclasses.gateway.networking.k8s.io &> /dev/null; then
    print_status "Gateway API CRDs already installed, skipping install"
else
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
    print_status "✅ Gateway API CRDs installed"
fi

# Step 2: Install local-path storage provisioner
print_status "Step 2: Installing local-path storage provisioner..."
if kubectl get storageclass local-path &> /dev/null; then
    print_status "local-path storage provisioner already installed, skipping install"
else
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
    print_status "✅ local-path storage provisioner installed and ready"
    # Wait for local-path provisioner to be ready
    print_status "Waiting for local-path provisioner to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/local-path-provisioner -n local-path-storage
fi

# Step 3: Install metrics-server
print_status "Step 3: Installing metrics-server..."
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    print_status "metrics-server already installed, skipping install"
else
    # Create service account first
    kubectl create serviceaccount metrics-server -n kube-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ClusterRole for metrics-server
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:metrics-server
rules:
- apiGroups:
  - ""
  resources:
  - nodes/metrics
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  verbs:
  - get
  - list
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - list
EOF
    
    # Create ClusterRoleBinding for metrics-server
    kubectl create clusterrolebinding system:metrics-server --clusterrole=system:metrics-server --serviceaccount=kube-system:metrics-server --dry-run=client -o yaml | kubectl apply -f -
    print_status "✅ metrics-server RBAC configured"
    
    # Create metrics-server deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
        - name: metrics-server
          image: registry.k8s.io/metrics-server/metrics-server:v0.7.1
          imagePullPolicy: IfNotPresent
          args:
            - --cert-dir=/tmp
            - --secure-port=10250
            - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
            - --kubelet-use-node-status-port
            - --metric-resolution=15s
            - --kubelet-insecure-tls
          ports:
            - containerPort: 10250
              name: https
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /readyz
              port: https
              scheme: HTTPS
            initialDelaySeconds: 20
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /livez
              port: https
              scheme: HTTPS
            initialDelaySeconds: 0
            periodSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 200Mi
          volumeMounts:
            - mountPath: /tmp
              name: tmp-dir
      nodeSelector:
        kubernetes.io/os: linux
      priorityClassName: system-cluster-critical
      serviceAccountName: metrics-server
      volumes:
        - emptyDir: {}
          name: tmp-dir
EOF
    print_status "Waiting for metrics-server to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/metrics-server -n kube-system
    print_status "✅ metrics-server installed and ready"
fi

# Step 4: Install cert-manager
print_status "Step 4: Installing cert-manager..."
if kubectl get deployment cert-manager -n cert-manager &> /dev/null; then
    print_status "cert-manager already installed, skipping install"
else
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
    # Wait for cert-manager to be ready
    print_status "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-cainjector -n cert-manager
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-webhook -n cert-manager
    print_status "✅ cert-manager installed and ready"
fi
# Step 5: Create Cloudflare API Token Secret
print_status "Step 5: Creating Cloudflare API Token Secret..."
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    print_status "⚠️  CLOUDFLARE_API_TOKEN environment variable not set"
    print_status "   Please set it with: export CLOUDFLARE_API_TOKEN=your_token_here"
    print_status "   Or create the secret manually:"
    print_status "   kubectl create secret generic cloudflare-api-token-secret --from-literal=api-token=YOUR_TOKEN -n cert-manager"
    print_status "   Skipping Cloudflare DNS-01 setup..."
else
    kubectl create secret generic cloudflare-api-token-secret \
        --from-literal=api-token="$CLOUDFLARE_API_TOKEN" \
        -n cert-manager --dry-run=client -o yaml | kubectl apply -f -
    print_status "✅ Cloudflare API Token Secret created"
fi

# Step 6: Create Let's Encrypt ClusterIssuers
print_status "Step 6: Creating Let's Encrypt ClusterIssuers..."

# HTTP-01 ClusterIssuer (for basic HTTP challenges)
if kubectl get clusterissuer letsencrypt-prod &> /dev/null; then
    print_status "letsencrypt-prod ClusterIssuer already exists, skipping creation"
else
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@maelkloud.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: istio
EOF
    print_status "✅ Let's Encrypt HTTP-01 ClusterIssuer created"
fi

# DNS-01 ClusterIssuer (for Cloudflare DNS challenges)
if [ ! -z "$CLOUDFLARE_API_TOKEN" ]; then
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns-cloudflare
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@maelkloud.com
    privateKeySecretRef:
      name: letsencrypt-dns-cloudflare
    solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token
EOF
    print_status "✅ Let's Encrypt DNS-01 ClusterIssuer created"
fi

# Step 7: Create istio-system namespace
# Note: Istio itself is now managed by Flux (platform/flux/apps/istio.yaml)
# We only create the namespace here as a prerequisite
print_status "Step 7: Creating istio-system namespace..."
if kubectl get namespace istio-system &> /dev/null; then
    print_status "istio-system namespace already exists, skipping creation"
else
    kubectl create namespace istio-system
    kubectl label namespace istio-system name=istio-system
    print_status "✅ istio-system namespace created"
fi

# Step 8: Verify installation
print_status "Step 8: Verifying installation..."

echo ""
print_status "Gateway API CRDs:"
kubectl get crd | grep gateway

echo ""
print_status "local-path storage provisioner:"
kubectl get pods -n local-path-storage

echo ""
print_status "Storage classes:"
kubectl get storageclass

echo ""
print_status "metrics-server:"
kubectl get pods -n kube-system -l k8s-app=metrics-server

echo ""
print_status "metrics-server RBAC:"
kubectl get clusterrole system:metrics-server 2>/dev/null || echo "ClusterRole not found"
kubectl get clusterrolebinding system:metrics-server 2>/dev/null || echo "ClusterRoleBinding not found"

echo ""
print_status "cert-manager pods:"
kubectl get pods -n cert-manager

echo ""
print_status "ClusterIssuers:"
kubectl get clusterissuer

echo ""
print_status "Cloudflare Secret (if created):"
kubectl get secret cloudflare-api-token-secret -n cert-manager 2>/dev/null || echo "Cloudflare secret not created (CLOUDFLARE_API_TOKEN not set)"

echo ""
print_status "istio-system namespace:"
kubectl get namespace istio-system 2>/dev/null || echo "Namespace not found"

echo ""
print_status "🎉 Prerequisites installation completed successfully!"
print_status ""
print_status "Next steps:"
print_status "  1. Install Flux: task install:flux"
print_status "  2. Configure Flux GitRepository: task flux:configure-repo"
print_status "  3. Install applications (including Istio): task install:apps"
print_status ""
print_status "Note: Istio is now managed by Flux and will be installed when you run 'task install:apps'"
