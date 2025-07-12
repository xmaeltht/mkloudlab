# ArgoCD Deployment via Helm

This directory contains the necessary Kubernetes manifests and Helm values to deploy ArgoCD into a Kubernetes cluster.

## Prerequisites

- A running Kubernetes cluster.
- `kubectl` configured to communicate with your cluster.
- Helm 3 installed.
- Cert-Manager installed in the cluster. See the [../cert-manager/README.md](../cert-manager/README.md) for instructions.

## Deployment Steps

These instructions assume you are deploying ArgoCD using the official Helm chart, customized with the values file provided in this repository.

1.  **Add the ArgoCD Helm repository:**

    ```bash
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    ```

2.  **Create the `argocd` namespace:**

    ```bash
    kubectl create namespace argocd
    ```

3.  **Deploy ArgoCD using Helm:**

    Navigate to the `argocd` directory and use the following command to deploy ArgoCD with the provided values file:

    ```bash
    helm install argocd argo/argo-cd --namespace argocd -f manifests/argocd-values.yaml
    ```

## Manifests Overview

The `manifests` directory contains the following files:

-   `argocd-values.yaml`: A Helm values file to customize the ArgoCD Helm chart deployment. This is the primary file used for configuration.
-   `gateway.yaml`, `gatewayclass.yaml`, `referencegrant.yaml`: These manifests are likely related to setting up an Ingress Gateway (like Contour or Istio) to expose the ArgoCD server.
-   `demo/`: This directory contains a sample application to be deployed with ArgoCD.
