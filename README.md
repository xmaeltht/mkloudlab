# Mkloudlab - Kubernetes GitOps Repository

Mkloudlab is the authoritative GitOps source for building and operating a production-grade Kubernetes platform. The repository bundles application manifests, infrastructure configuration, automation scripts, and operational runbooks so the entire stack can be managed from a single, versioned control point.

## Repository Structure
- `platform/`: ArgoCD bootstrap assets and platform capabilities (cert-manager, Istio, Kyverno, security, observability).
- `services/`: Workload-specific manifests and supporting configuration for Keycloak, SonarQube, and related gateways.
- `infrastructure/`: Provisioning and infrastructure-as-code assets, including Terraform modules and Vagrant environments.
- `scripts/`: Operational shell scripts for setup, prerequisite installation, and recovery workflows.
- `docs/`: Consolidated documentation, runbooks, reports, and security guidance.
- `Taskfile.yml`, `docs/reference/TASKS.md`, `docs/reference/TASKFILE_QUICKSTART.md`: Task automation entry points, reference, and quick-start guide.

Welcome to the Mkloudlab GitOps repository. This project provides a complete, automated setup for a Kubernetes cluster, deploying a suite of powerful open-source applications using ArgoCD. It serves as a blueprint for building a robust, secure, and observable cloud-native environment.

## Core Technologies

This platform is built on a foundation of industry-standard cloud-native tools:

-   **Container Orchestration:** Kubernetes
-   **GitOps Controller:** ArgoCD
-   **Ingress & Gateway:** Istio with Gateway API
-   **Load Balancer:** MetalLB
-   **Certificate Management:** Cert-Manager with Let's Encrypt
-   **Identity & Access Management:** Keycloak
-   **Policy Enforcement:** Kyverno
-   **Code Quality:** SonarQube
-   **Monitoring & Observability:** Prometheus & Grafana with Alertmanager, Grafana Alloy collector
-   **Tracing:** Grafana Tempo (OTLP compatible)
-   **Centralized Logging:** Loki Stack
-   **Secrets Management:** External Secrets Operator
-   **Security:** Pod Security Standards, RBAC, Network Policies
-   **Object Storage:** External S3-compatible provider (bring your own)
-   **Infrastructure as Code:** Terraform (for Keycloak configuration)
-   **Local Provisioning:** Vagrant & Kubeadm

## Automated Deployment with ArgoCD

This repository uses **independent ArgoCD applications** to deploy the entire stack. After provisioning a Kubernetes cluster, the process is reduced to two main steps.

### 1. Install ArgoCD

First, install ArgoCD into your cluster. The manifests for this are in the `argocd/manifests` directory.

```bash
# Create the namespace for ArgoCD
kubectl create namespace argocd

# Apply the ArgoCD installation manifests
kubectl apply -n argocd -f platform/argocd/manifests/argocd-values.yaml
```

### 2. Deploy the Entire Stack

With ArgoCD running, deploy all applications independently from the `argocd/apps` directory:

```bash
kubectl apply -f platform/argocd/apps/
```

ArgoCD will now begin deploying and configuring all applications independently. You can monitor the progress from the ArgoCD UI.

### 3. Post-Deployment Configuration

Some applications require secrets or configurations that should not be stored in Git. After the main deployment is complete, run the following scripts:

-   **Keycloak Configuration:** Use the Terraform scripts in `infrastructure/terraform/keycloak-realm` to configure realms and clients.
-   **Application Secrets:** Run the `secret.sh` script in that directory to create the necessary OAuth secrets for Grafana, Prometheus, etc.

## Using Taskfile for Automation

This repository now includes comprehensive Taskfile automation to streamline your GitOps workflows. Taskfile provides a simple, powerful way to automate repetitive tasks and complex operations.

### Prerequisites Setup

Before deploying applications, install the required prerequisites:

```bash
# Set up Cloudflare API token (for automated TLS certificates)
./scripts/setup-cloudflare-token.sh

# Install all prerequisites (Gateway API, local-path storage, metrics-server, cert-manager, Istio)
task install:prerequisites
```

### Cloudflare Token Setup

For automated TLS certificate management, you need a Cloudflare API token:

1. **Create API Token**: Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. **Set Permissions**: Zone:Read and DNS:Edit
3. **Run Setup Script**: `./scripts/setup-cloudflare-token.sh`

The script will:
- Guide you through token creation
- Set up environment variables
- Test the token
- Enable automated certificate management

## Quick Start
```bash
# Install Task (if not already installed)
brew install go-task/tap/go-task

# Show all available tasks
task

# Install the complete stack
task install

# Check status
task status
```

### Key Benefits
- **Simplified Operations**: One command to install the entire stack
- **Consistent Workflows**: Standardized tasks for development and operations
- **Error Handling**: Built-in validation and error checking
- **Component Management**: Specialized tasks for Terraform, Vagrant, and ArgoCD
- **Development Tools**: Linting, formatting, and validation automation

For detailed usage instructions, see [TASKFILE_QUICKSTART.md](./docs/reference/TASKFILE_QUICKSTART.md).

## 🔒 Security Features

This repository implements enterprise-grade security features:

- **Pod Security Standards**: Enforced across all namespaces with appropriate restriction levels
- **Network Policies**: Comprehensive micro-segmentation with zero-trust networking
- **RBAC Policies**: Fine-grained access control with principle of least privilege
- **External Secrets Management**: Secure secrets handling without Git storage
- **Security Monitoring**: Enhanced observability with security-focused metrics and alerting

### Security Commands

```bash
# Run comprehensive security scan
task security:scan

# Validate security configurations
task security:validate

# Check external secrets status
task secrets:status

# Enhanced health check (includes security status)
task health
```

### Validation Commands

```bash
# Validate all Kubernetes manifests (syntax validation only)
task validate:manifests

# Validate manifests against running cluster (requires cluster connection)
task validate:manifests:cluster

# Validate cluster connectivity and prerequisites
task validate:cluster

# Check certificate status across all namespaces
task certs:status

# Comprehensive health check of all components
task health
```

For detailed security documentation, see [SECURITY_ENHANCEMENTS.md](./docs/security/SECURITY_ENHANCEMENTS.md).

## Observability with Grafana Alloy & OpenTelemetry

Grafana Alloy runs as a daemonset in the `observability` namespace and exposes OTLP endpoints (`otlp-grpc`, `otlp-http`) through the `alloy-gateway` service. Instrument workloads with OpenTelemetry SDKs or auto-instrumentation agents and point them to:

```
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy-gateway.observability:4318
```

- Metrics are remote-written into the in-cluster Prometheus instance.
- Logs are shipped to the Loki stack, replacing Promtail requirements.
- Traces are stored in Grafana Tempo (`platform/observability/tempo`) with long-term persistence.

The Alloy manifests are managed at `platform/observability/alloy` (ArgoCD app `platform/argocd/apps/alloy-app.yaml`). Tempo is provisioned via Helm using `platform/argocd/apps/tempo-app.yaml`.

## Repository Structure

Each directory contains the Kubernetes manifests or configuration for a specific component. Click the links for detailed deployment instructions.

| Directory                               | Description                                                                        |
| --------------------------------------- | ---------------------------------------------------------------------------------- |
| [platform/](./platform/)                | Platform building blocks including ArgoCD, cert-manager, Istio, Kyverno, security, and observability. |
| [platform/argocd/](./platform/argocd/)  | ArgoCD installation manifests, the root application, and all child application definitions. |
| [platform/observability/prometheus-grafana/](./platform/observability/prometheus-grafana/) | Prometheus, Grafana, ServiceMonitors, and supporting observability configuration. |
| [platform/observability/alloy/](./platform/observability/alloy/) | Grafana Alloy collector (OTLP ingestion, log shipping, metrics fan-out). |
| [platform/observability/tempo/](./platform/observability/tempo/) | Grafana Tempo trace storage (Helm chart + persistence). |
| [services/](./services/)                | Workload services such as Keycloak and SonarQube with their gateways and related configuration. |
| [infrastructure/terraform/](./infrastructure/terraform/) | Terraform code to manage Keycloak realms, secrets, and other external integrations. |
| [infrastructure/vagrant/](./infrastructure/vagrant/) | Vagrant assets for provisioning a local multi-node Kubernetes cluster. |
| [scripts/](./scripts/)                  | Automation scripts for installation, Cloudflare token setup, and cluster recovery tasks. |
| [docs/](./docs/)                        | Runbooks, reference guides, reports, and security documentation for day-2 operations. |
