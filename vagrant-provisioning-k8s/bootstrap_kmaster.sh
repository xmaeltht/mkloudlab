#!/bin/bash

set -e

echo "[TASK 1] Pull required containers"
kubeadm config images pull

echo "[TASK 2] Initialize Kubernetes Cluster"
kubeadm init --apiserver-advertise-address=172.16.16.100 --pod-network-cidr=192.168.0.0/16

echo "[TASK 3] Taint all nodes to prevent pod scheduling before CNI is ready"
kubectl --kubeconfig=/etc/kubernetes/admin.conf taint nodes --all node.cilium.io/agent-not-ready=true:NoSchedule

echo "[TASK 4] Install Cilium CLI"
export KUBECONFIG=/etc/kubernetes/admin.conf
CILIUM_CLI_VERSION=v0.18.3
ARCH=amd64

if [ "$(uname -m)" = "aarch64" ]; then ARCH=arm64; fi

curl -LO https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz
curl -LO https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz.sha256sum
sha256sum --check cilium-linux-${ARCH}.tar.gz.sha256sum
sudo tar xzvf cilium-linux-${ARCH}.tar.gz -C /usr/local/bin
rm cilium-linux-${ARCH}.tar.gz{,.sha256sum}

cilium version

echo "[TASK 5] Deploy Cilium CNI"
export KUBECONFIG=/etc/kubernetes/admin.conf
cilium install \
  --version 1.17.4 \
  --set cluster.poolIPv4PodCIDR=192.168.0.0/16 \
  --set ipam.operator.clusterPoolIPv4PodCIDRList='{192.168.0.0/16}' \
  --set ipam.mode=cluster-pool \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=172.16.16.100 \
  --set k8sServicePort=6443 \
  --wait


echo "[TASK 6] Un-taint nodes to allow scheduling"
kubectl --kubeconfig=/etc/kubernetes/admin.conf taint nodes --all node.cilium.io/agent-not-ready:NoSchedule-

echo "[TASK 7] Generate and save cluster join command to /joincluster.sh"
kubeadm token create --print-join-command > /joincluster.sh
chmod +x /joincluster.sh
