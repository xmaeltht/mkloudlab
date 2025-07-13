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

## Deployment Flow

The general deployment process follows the principles of GitOps, where the state of the cluster is defined declaratively in this repository.

1.  **Provision Cluster:** Use the scripts in the `vagrant-provisioning-k8s` directory to spin up a local Kubernetes cluster.
2.  **Install Prerequisites:** Deploy core infrastructure services. This is the recommended order:
    -   [Traefik](./traefik/README.md): To handle all incoming cluster traffic.
    -   [Cert-Manager](./cert-manager/README.md): To automate TLS certificate management.
3.  **Deploy ArgoCD:** Install the GitOps controller using the manifests in the [argocd](./argocd/README.md) directory.
4.  **Deploy Applications:** With ArgoCD running, deploy the applications by applying their respective ArgoCD `Application` manifests, as detailed in their `README.md` files.
5.  **Configure Keycloak:** Use the Terraform scripts in `terraform/keycloak-realm` to configure realms, clients, and users in your Keycloak instance.

## Repository Structure

Each directory contains the Kubernetes manifests or configuration for a specific component. Click the links for detailed deployment instructions.

| Directory                               | Description                                                                        |
| --------------------------------------- | ---------------------------------------------------------------------------------- |
| [argocd](./argocd/)                     | Manifests to deploy the ArgoCD GitOps controller.                                  |
| [cert-manager](./cert-manager/)         | Manifests to deploy Cert-Manager for automated TLS certificates.                   |
| [traefik](./traefik/)                   | Manifests for the Traefik Ingress Controller.                                      |
| [kyverno](./kyverno/)                   | Kyverno policy engine and a set of custom security policies.                       |
| [keycloak](./keycloak/)                 | Manifests for the Keycloak Identity and Access Management server.                  |
| [sonarqube](./sonarqube/)               | Manifests for the SonarQube static code analysis platform.                         |
| [prometheus-grafana](./prometheux&grafana/) | Manifests for the Prometheus & Grafana monitoring stack.                           |
| [jenkins](./jenkins/)                   | Manifests for the Jenkins CI/CD automation server.                                 |
| [velero-backup](./velero-backup/)       | Manifests for Velero and MinIO to handle cluster backup and restore.               |
| [terraform/keycloak-realm](./terraform/keycloak-realm/) | Terraform code to manage Keycloak realms, clients, and users declaratively.        |
| [vagrant-provisioning-k8s](./vagrant-provisioning-k8s/) | Scripts to provision a local multi-node Kubernetes cluster using Vagrant.          |
