# ArgoCD and the "App of Apps" Pattern

This directory is the heart of the GitOps automation for the Mkloudlab repository. It contains not only the manifests to install ArgoCD but also the configuration for the **"App of Apps" pattern**, which allows ArgoCD to deploy and manage every other application in the cluster.

## How It Works: The App of Apps Pattern

The "App of Apps" is a powerful pattern where a single, top-level ArgoCD `Application` (the "root app") is responsible for deploying a collection of other "child" `Applications`.

1.  **The Root App (`root-app.yaml`):** This is the single entry point for our entire stack. When you apply this manifest to the cluster, it creates a root `Application` in ArgoCD.

2.  **The Apps Directory (`apps/`):** The root app is configured to monitor the `argocd/apps/` directory. This directory contains a separate ArgoCD `Application` manifest for each service in our stack (e.g., `traefik-app.yaml`, `keycloak-app.yaml`, etc.).

3.  **Automated Deployment:** ArgoCD detects all the application manifests in the `apps/` directory and automatically creates them. Each of these child applications then syncs the actual service manifests from their respective directories (e.g., `/traefik`, `/keycloak`), deploying them to the cluster.

This creates a declarative, hierarchical structure that allows you to manage the entire application stack from a single Git repository.

## Automated Deployment Flow

For the complete, automated deployment flow, please refer to the [main repository README.md](../README.md#automated-deployment-with-argocd).

## Directory Structure

-   `manifests/`: Contains the base installation manifests for the ArgoCD controller itself.
-   `apps/`: Contains the individual ArgoCD `Application` manifests for every service deployed in the cluster. This is the collection of "child" apps.
-   `root-app.yaml`: The main "App of Apps" manifest. This is the **only** application you need to apply manually after ArgoCD is running.
