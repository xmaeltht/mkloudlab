# Kubernetes Cluster Provisioning with Vagrant for macOS M-series

This project provides an automated way to set up a production-grade Kubernetes cluster on macOS M-series (Apple Silicon) using Vagrant with VirtualBox. The cluster is pre-configured with Cilium as the CNI (Container Network Interface) and includes essential add-ons like NFS dynamic volume provisioning and MetalLB load balancing.

The setup is specifically optimized for:

- macOS M-series (Apple Silicon) with VirtualBox
- High-performance networking using Cilium CNI with eBPF
- Production-ready resource allocation (16GB RAM, 8 vCPUs per node)
- Ubuntu 24.04 LTS as the base operating system

## Table of Contents

- [Prerequisites](#prerequisites)
- [Windows Setup Guide](#windows-setup-guide)
  - [Install Prerequisites](#1-install-prerequisites)
  - [Modify Vagrantfile for Windows](#2-modify-vagrantfile-for-windows)
  - [Network Configuration for Windows](#3-network-configuration-for-windows)
  - [Start the Cluster](#4-start-the-cluster)
  - [Windows-Specific Notes](#5-windows-specific-notes)
- [Quick Start (macOS/Linux)](#quick-start-macoslinux)
  - [Clone the Repository](#1-clone-the-repository)
  - [Start the Cluster](#2-start-the-cluster)
  - [Access the Cluster](#3-access-the-cluster)
  - [Verify Cilium Installation](#4-verify-cilium-installation)
  - [Enable Hubble for Observability](#5-optional-enable-hubble-for-observability)
- [Cluster Architecture](#cluster-architecture)
- [Add-ons](#add-ons)
  - [NFS Subdir External Provisioner](#nfs-subdir-external-provisioner)
  - [MetalLB Load Balancer](#metallb-load-balancer)
  - [Istio Service Mesh](#istio-service-mesh)
- [Maintenance](#maintenance)
  - [Destroy the Cluster](#destroy-the-cluster)
  - [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

#### macOS M-series (Apple Silicon)

- Apple Silicon (M1/M2/M3) Mac
- macOS 12.0 (Monterey) or later
- [Vagrant](https://www.vagrantup.com/downloads) (2.4.0 or later)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (7.0.12 or later) with Apple Silicon support
- Rosetta 2 installed (required for x86_64 emulation)
- At least 16GB RAM (32GB recommended for better performance)
- At least 200GB free disk space (SSD recommended)

#### Windows

> **Important**: If you're using Windows, you'll need to use a different Vagrant box that supports Windows. The current configuration is optimized for macOS with Apple Silicon.

- Windows 10/11 (64-bit)
- [Vagrant](https://www.vagrantup.com/downloads) (2.4.0 or later)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (7.0.12 or later) or [Hyper-V](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v)
- At least 16GB RAM (32GB recommended)
- At least 200GB free disk space (SSD recommended)
- [Windows Subsystem for Linux 2 (WSL 2)](https://learn.microsoft.com/en-us/windows/wsl/install) (recommended for better performance)

> **Note for Windows Users**:
>
> 1. You'll need to modify the `Vagrantfile` to use a Windows-compatible box (e.g., `generic/ubuntu2204`)
> 2. Update the provider configuration for your hypervisor (VirtualBox or Hyper-V)
> 3. Network configurations might need adjustments based on your Windows network setup
> 4. Consider using WSL 2 with Ubuntu for better performance and compatibility

### Network Requirements

- Stable internet connection for downloading packages and container images
- Administrative access to configure network interfaces
- Ports 30000-32767 should be available for NodePort services

### Cilium CNI

This cluster uses Cilium as the default CNI, providing:

- eBPF-based networking and security
- High-performance load balancing with XDP
- Network policy enforcement
- Transparent encryption
- Hubble observability (optional)

> **Note**: The setup is specifically tested on Apple Silicon Macs with VirtualBox. While KVM/Libvirt is technically supported, VirtualBox is the recommended provider for M-series Macs.

## Windows Setup Guide

If you're using Windows, follow these additional steps to set up the environment:

### 1. Install Prerequisites

1. **Enable WSL 2** (Recommended):

   ```powershell
   wsl --install
   ```

   This will install WSL 2 with Ubuntu by default.

2. **Install VirtualBox** or **Enable Hyper-V**:
   - [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads)
   - OR Enable Hyper-V:
     ```powershell
     Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
     ```

### 2. Modify Vagrantfile for Windows

You'll need to update the `Vagrantfile` with Windows-compatible settings. Here's what to change:

```ruby
# Change the box to a Windows-compatible one
VAGRANT_BOX = "generic/ubuntu2204"
VAGRANT_BOX_VERSION = "4.3.8"  # Use the latest version

# Update provider configuration
config.vm.provider "virtualbox" do |v|
  v.name = "k8s-master-win"
  v.memory = MEMORY_MASTER_NODE
  v.cpus = CPUS_MASTER_NODE
  # Add these lines for better performance on Windows
  v.customize ["modifyvm", :id, "--ioapic", "on"]
  v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  v.customize ["modifyvm", :id, "--rtcuseutc", "on"]
end
```

### 3. Network Configuration for Windows

Windows might require additional network configuration:

1. **For VirtualBox**:
   - Go to VirtualBox Preferences > Network > Host-only Networks
   - Create a new host-only network with these settings:
     - IPv4 Address: 172.16.16.1
     - Network Mask: 255.255.255.0
     - DHCP Server: Disabled

2. **For Hyper-V**:
   - Open Hyper-V Manager
   - Create a new Virtual Switch with External network type
   - Configure the network adapter to use this switch

### 4. Start the Cluster

```powershell
# Start the cluster with VirtualBox
vagrant up --provider=virtualbox

# OR with Hyper-V (run as Administrator)
vagrant up --provider=hyperv
```

### 5. Windows-Specific Notes

- **Performance**: For better performance, run Vagrant commands from WSL 2 terminal
- **File Sharing**: Use `config.vm.synced_folder` with proper Windows paths
- **Line Endings**: Ensure your Git is configured with `core.autocrlf = input`
- **Antivirus**: Add VirtualBox/Hyper-V directories to your antivirus exclusion list

## Quick Start (macOS/Linux)

### 1. Clone the Repository

```bash
git clone https://github.com/justmeandopensource/kubernetes
cd kubernetes/vagrant-provisioning
```

### 2. Start the Cluster

For optimal performance on Apple Silicon, we'll use VirtualBox with specific settings:

```bash
# Start the cluster with VirtualBox provider
vagrant up --provider=virtualbox

# Check the status of the cluster
vagrant status
```

> **Note**: The first boot may take 10-15 minutes as it downloads the Ubuntu 24.04 box and provisions the cluster.

### 3. Access the Cluster

#### Using Taskfile (Recommended)

```bash
# Start the cluster and automatically set up kubeconfig
task vagrant:up

# Or manually set up kubeconfig
task vagrant:kubeconfig

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

#### Manual Setup

```bash
# Create kubeconfig directory if it doesn't exist
mkdir -p ~/.kube

# Copy kubeconfig from the master node
scp -o StrictHostKeyChecking=no root@172.16.16.100:/etc/kubernetes/admin.conf ~/.kube/config

# Set proper permissions
chmod 600 ~/.kube/config

# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Check Cilium status
kubectl -n kube-system get pods -l k8s-app=cilium
```

#### Using the Setup Script

```bash
# Use the provided setup script
chmod +x setup-kubeconfig.sh
./setup-kubeconfig.sh
```

### 4. Verify Cilium Installation

```bash
# Check Cilium status
cilium status

# Check Cilium connectivity
cilium connectivity test

# View Cilium endpoints
kubectl get ciliumendpoints.cilium.io -A
```

Default credentials:

- Username: `root`
- Password: `kubeadmin`

### 5. (Optional) Enable Hubble for Observability

```bash
# Enable Hubble
cilium hubble enable

# Port-forward Hubble UI
cilium hubble ui
```

## Taskfile Automation

This project includes comprehensive Taskfile automation for streamlined cluster management:

### Available Tasks

```bash
# Show all available tasks
task vagrant

# Start the cluster and set up kubeconfig
task vagrant:up

# Set up kubeconfig only
task vagrant:kubeconfig

# Wait for cluster to be ready
task vagrant:wait-ready

# Check cluster status
task vagrant:status

# SSH into control plane
task vagrant:ssh

# SSH into worker node
task vagrant:ssh-worker -- knode1

# Stop cluster
task vagrant:halt

# Destroy cluster
task vagrant:destroy
```

### Key Features

- **Automatic kubeconfig setup** with port forwarding (localhost:6443)
- **TLS certificate handling** for localhost access
- **Hostname resolution** fixes for proper cluster communication
- **Port forwarding** for Kubernetes API server (6443) and web services (8080)
- **Comprehensive status checking** and health monitoring

## Cluster Architecture

The cluster consists of the following nodes:

- 1 Master Node (kcontroller)
  - IP: 172.16.16.100
  - Hostname: kcontroller.example.com
  - 8 vCPUs
  - 16GB RAM
  - 200GB Disk
  - Port forwarding: 6443 (Kubernetes API), 8080 (web services)

- 3 Worker Nodes (knode1, knode2, knode3)
  - IPs: 172.16.16.101, 172.16.16.102, 172.16.16.103
  - Hostnames: knode1.example.com, knode2.example.com, knode3.example.com
  - 8 vCPUs each
  - 16GB RAM each
  - 200GB Disk each

## Add-ons

### NFS Subdir External Provisioner

This add-on provides dynamic volume provisioning using NFS.

```bash
cd misc/nfs-subdir-external-provisioner

# Set up NFS on all nodes
cat setup_nfs | vagrant ssh controller
cat setup_nfs | vagrant ssh knode1
cat setup_nfs | vagrant ssh knode2

# Deploy the NFS provisioner
kubectl create -f 01-setup-nfs-provisioner.yaml

# Test the NFS provisioner
kubectl create -f 02-test-claim.yaml
# Cleanup test
kubectl delete -f 02-test-claim.yaml
```

### MetalLB Load Balancer

MetalLB provides network load-balancer implementation for bare metal Kubernetes clusters.

```bash
cd misc/metallb

# Install MetalLB
kubectl create -f 01_metallb.yaml

# Wait for pods to be ready (about 10 seconds)
sleep 10

# Configure MetalLB with Layer 2 mode
kubectl create -f 02_metallb-config.yaml

# Test the load balancer
kubectl create -f 03_test-load-balancer.yaml
# Cleanup test
kubectl delete -f 03_test-load-balancer.yaml
```

### Istio Service Mesh

Istio is a service mesh that provides traffic management, security, and observability to microservices.

```bash
# Download and install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.x.x # Replace with the downloaded version
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y

# Deploy a sample application
kubectl label namespace default istio-injection=enabled
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

# Verify the installation
kubectl get services
kubectl get pods
```

## Maintenance

### Destroy the Cluster

To completely remove the cluster and all its resources:

```bash
vagrant destroy -f
```

## Troubleshooting

### Common Issues and Solutions

#### Kubeconfig Access Issues

If you can't access the cluster via kubectl:

1. **Port forwarding not working**:

   ```bash
   # Check if port 6443 is forwarded
   vagrant port kcontroller

   # Restart the controller to apply port forwarding
   vagrant reload kcontroller
   ```

2. **TLS certificate errors**:

   ```bash
   # The kubeconfig is automatically configured for localhost access
   # If you get certificate errors, use the Taskfile setup
   task vagrant:kubeconfig
   ```

3. **Hostname resolution issues**:

   ```bash
   # Check /etc/hosts on VMs
   vagrant ssh kcontroller -- cat /etc/hosts

   # Verify hostnames are correct
   vagrant ssh kcontroller -- hostname
   ```

#### Cluster Startup Issues

4. **Worker nodes not joining**:

   ```bash
   # Check worker node logs
   task vagrant:logs

   # Verify join command was executed
   vagrant ssh knode1 -- cat /joincluster.sh
   ```

5. **Bootstrap script errors**:

   ```bash
   # Check bootstrap logs
   vagrant ssh kcontroller -- journalctl -u kubelet

   # Re-run provisioning
   task vagrant:provision
   ```

### macOS M-series Specific Issues

1. **VirtualBox Kernel Module Issues**

   ```bash
   # Rebuild kernel modules
   sudo /sbin/vboxconfig

   # Check VirtualBox kernel module status
   kextstat | grep -i vbox
   ```

2. **Rosetta 2 Not Installed**

   ```bash
   # Install Rosetta 2 if not present
   softwareupdate --install-rosetta
   ```

3. **Performance Issues**
   - Ensure you're using an SSD
   - Allocate more CPU cores if available
   - Increase VirtualBox's base memory in Vagrantfile

### Cilium Issues

4. **Cilium Pods Not Starting**

   ```bash
   # Check Cilium pod status
   kubectl -n kube-system get pods -l k8s-app=cilium

   # Check Cilium logs
   kubectl -n kube-system logs -l k8s-app=cilium
   ```

5. **Network Connectivity Issues**

   ```bash
   # Run Cilium connectivity test
   cilium connectivity test

   # Check Cilium endpoint health
   cilium status
   ```

6. **Hubble UI Not Accessible**

   ```bash
   # Check Hubble pods
   kubectl -n kube-system get pods -l k8s-app=hubble-ui

   # Check Hubble service
   kubectl -n kube-system get svc hubble-ui

   # Port-forward Hubble UI
   kubectl -n kube-system port-forward svc/hubble-ui 8080:80
   ```

### General Kubernetes Issues

7. **Kubernetes Components Not Starting**

   ```bash
   # Check all pods in kube-system
   kubectl -n kube-system get pods

   # Check kubelet logs
   journalctl -u kubelet -f
   ```

8. **NFS Provisioner Issues**

   ```bash
   # Check NFS server status on nodes
   vagrant ssh controller -- systemctl status nfs-kernel-server

   # Check provisioner logs
   kubectl logs -n nfs-provisioner -l app=nfs-client-provisioner
   ```

9. **MetalLB Not Working**

   ```bash
   # Check MetalLB controller logs
   kubectl logs -n metallb-system -l app=metallb,component=controller

   # Check MetalLB speaker logs
   kubectl logs -n metallb-system -l app=metallb,component=speaker
   ```

### Resource Monitoring

10. **Check Cluster Resources**

    ```bash
    # Check node resource usage
    kubectl top nodes

    # Check pod resource usage
    kubectl top pods -A

    # Check disk usage on nodes
    vagrant ssh controller -- df -h
    ```

## License

This project is open source and available under the [MIT License](LICENSE).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
