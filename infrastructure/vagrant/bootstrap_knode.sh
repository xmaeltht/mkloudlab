#!/bin/bash


echo "[TASK 1] Join node to Kubernetes Cluster"
export DEBIAN_FRONTEND=noninteractive
apt-get install -qq -y sshpass
sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no kcontroller.example.com:/joincluster.sh /joincluster.sh
bash /joincluster.sh >/dev/null

echo "[TASK 2] Add worker role label to node"
# Wait for the node to be ready and then add the worker role label
sleep 30
# Get the current hostname and add worker role label
HOSTNAME=$(hostname)
sshpass -p "kubeadmin" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no kcontroller.example.com "sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl label node $HOSTNAME node-role.kubernetes.io/worker=worker --overwrite"

