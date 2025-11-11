# ArgoCD Independent Applications

This directory contains the ArgoCD installation manifests and individual application definitions for independent deployment of each service in the Mkloudlab repository.

## How It Works: Independent Applications

Each service in the cluster is deployed as an independent ArgoCD `Application`. This approach provides:

1. **Independent Management**: Each application can be managed separately
2. **Flexible Deployment**: Deploy only the services you need
3. **Simplified Troubleshooting**: Issues with one service don't affect others
4. **Easy Scaling**: Add or remove services without affecting the entire stack

### Deployment Process

1. **Install ArgoCD**: Deploy the ArgoCD controller using the manifests in `manifests/`
2. **Deploy Applications**: Apply all application manifests from the `apps/` directory
3. **Monitor Progress**: Each application syncs independently from its respective directory

## Automated Deployment Flow

For the complete, automated deployment flow, please refer to the [main repository README.md](../README.md#automated-deployment-with-argocd).

## Directory Structure

- `manifests/`: Contains the base installation manifests for the ArgoCD controller itself.
- `apps/`: Contains individual ArgoCD `Application` manifests for each service deployed in the cluster. Each application is independent and can be managed separately.
