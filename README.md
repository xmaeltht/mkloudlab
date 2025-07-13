# Mkloudlab - Kubernetes GitOps Repository

Welcome to the Mkloudlab GitOps repository. This project provides a complete, automated setup for a Kubernetes cluster, deploying a suite of powerful open-source applications using ArgoCD. It serves as a blueprint for building a robust, secure, and observable cloud-native environment.

## Core Technologies

This platform is built on a foundation of industry-standard cloud-native tools:

-   **Container Orchestration:** Kubernetes
-   **GitOps Controller:** ArgoCD
-   **Ingress & Gateway:** Traefik
-   **Certificate Management:** Cert-Manager with Let's Encrypt
-   **Identity & Access Management:** Keycloak
-   **Policy Enforcement:** Kyverno
-   **CI/CD:** Jenkins
-   **Code Quality:** SonarQube
-   **Monitoring & Observability:** Prometheus & Grafana
-   **Backup & Recovery:** Velero & MinIO
-   **Infrastructure as Code:** Terraform (for Keycloak configuration)
-   **Local Provisioning:** Vagrant & Kubeadm

## Automated Deployment with ArgoCD

This repository uses the **App of Apps** pattern to fully automate the deployment of the entire stack. After provisioning a Kubernetes cluster, the process is reduced to two main steps.

### 1. Install ArgoCD

First, install ArgoCD into your cluster. The manifests for this are in the `argocd/manifests` directory.

```bash
# Create the namespace for ArgoCD
kubectl create namespace argocd

# Apply the ArgoCD installation manifests
kubectl apply -n argocd -f argocd/manifests/argocd-values.yaml
```

### 2. Deploy the Entire Stack

With ArgoCD running, apply the `root-app.yaml`. This single manifest is the entry point for the "App of Apps" pattern. It tells ArgoCD to deploy all other applications defined in the `argocd/apps` directory.

```bash
kubectl apply -f argocd/root-app.yaml
```

ArgoCD will now begin deploying and configuring the entire stack in the correct order. You can monitor the progress from the ArgoCD UI.

### 3. Post-Deployment Configuration

Some applications require secrets or configurations that should not be stored in Git. After the main deployment is complete, run the following scripts:

-   **Keycloak Configuration:** Use the Terraform scripts in `terraform/keycloak-realm` to configure realms and clients.
-   **Application Secrets:** Run the `secret.sh` script in the same directory to create the necessary OAuth secrets for Grafana, Prometheus, etc.

## Repository Structure

Each directory contains the Kubernetes manifests or configuration for a specific component. Click the links for detailed deployment instructions.

| Directory                               | Description                                                                        |
| --------------------------------------- | ---------------------------------------------------------------------------------- |
| [argocd](./argocd/)                     | Contains the ArgoCD installation, the **root application**, and all child app manifests. |
| [cert-manager](./cert-manager/)         | Manifests to deploy Cert-Manager for automated TLS certificates.                   |
| [traefik](./traefik/)                   | Manifests for the Traefik Ingress Controller.                                      |
| [kyverno](./kyverno/)                   | Kyverno policy engine and a set of custom security policies.                       |
| [keycloak](./keycloak/)                 | Manifests for the Keycloak Identity and Access Management server.                  |
| [sonarqube](./sonarqube/)               | Manifests for the SonarQube static code analysis platform.                         |
| [prometheus-grafana](./prometheus-grafana/) | Manifests for Prometheus & Grafana for monitoring.                                 |
| [jenkins](./jenkins/)                   | Manifests for the Jenkins CI/CD automation server.                                 |
| [velero-backup](./velero-backup/)       | Manifests for Velero and MinIO to handle cluster backup and restore.               |
| [terraform/keycloak-realm](./terraform/keycloak-realm/) | Terraform code to manage Keycloak realms, clients, and users declaratively.        |
| [vagrant-provisioning-k8s](./vagrant-provisioning-k8s/) | Scripts to provision a local multi-node Kubernetes cluster using Vagrant.          |
