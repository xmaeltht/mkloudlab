# mkloudlab - Available Tasks

This file is auto-generated. Run `task docs` to update.

task: Available tasks for this project:
* access:                             Show access URLs for all services
* backup:                             Backup cluster state and configurations
* clean:                              Clean up temporary files and reset
* default:                            Show available tasks
* docs:                               Generate or update documentation
* format:                             Format code with prettier
* health:                             Comprehensive health check of all components
* install:                            Install the entire stack (Prerequisites + Flux + Apps) - Full GitOps workflow
* lint:                               Lint all YAML files
* logs:                               View logs for a specific component
* reset:                              Reset the entire deployment (uninstall + clean + install)
* shell:                              Get a shell in a component pod
* status:                             Show status of all deployments
* troubleshoot:                       Collect troubleshooting information
* uninstall:                          Uninstall the entire stack
* certificates:apply-all:             Apply all certificate manifests
* certificates:configure-token:       Configure Cloudflare API token for certificate issuance
* certificates:describe:              Describe certificate issues for troubleshooting
* certificates:status:                Check certificate status across all namespaces
* dns:check:                          Check DNS resolution for maelkloud.com subdomains
* flux:configure-repo:                Configure Flux GitRepository (required for GitOps)
* flux:status:                        Show Flux status
* flux:sync-all:                      Force reconcile all Flux resources
* gateway:status:                     Check Gateway API resources status
* gitops:ensure-committed:            Ensure all changes are committed and pushed to Git (required for Flux GitOps)
* gitops:push:                        Commit and push all changes to Git repository
* install:apps:                       Register all Flux applications (they will sync automatically)
* install:certificates:               Install and configure TLS certificates with Cloudflare DNS-01
* install:flux:                       Install Flux in the cluster (requires prerequisites)
* install:prerequisites:              Install prerequisites (Gateway API, local-path storage, metrics-server, cert-manager, Istio)
* secrets:status:                     Check external secrets status
* security:scan:                      Run security scan on cluster
* security:validate:                  Validate security configurations
* terraform:apply:                    Apply Terraform changes
* terraform:clean:                    Clean Terraform temporary files
* terraform:default:                  Show Terraform tasks      (aliases: terraform)
* terraform:destroy:                  Destroy Terraform-managed resources
* terraform:format:                   Format Terraform files
* terraform:init:                     Initialize Terraform
* terraform:keycloak:setup:           Complete Keycloak setup (Terraform + Secrets)
* terraform:output:                   Show Terraform outputs
* terraform:plan:                     Plan Terraform changes
* terraform:secrets:create:           Create OAuth secrets for applications
* terraform:validate:                 Validate Terraform configuration
* uninstall:prerequisites:            Uninstall all prerequisites (Gateway API, local-path storage, metrics-server, cert-manager, Istio)
* vagrant:backup:                     Backup cluster configuration
* vagrant:clean:                      Clean up Vagrant and VM artifacts
* vagrant:debug:                      Collect debugging information
* vagrant:default:                    Show Vagrant tasks      (aliases: vagrant)
* vagrant:destroy:                    Destroy all Vagrant VMs
* vagrant:halt:                       Stop all Vagrant VMs
* vagrant:ip:                         Show IP addresses of cluster nodes
* vagrant:kubeconfig:                 Copy kubeconfig from control plane (safely merges with existing config)
* vagrant:logs:                       View logs from bootstrap scripts
* vagrant:provision:                  Re-run provisioning on existing VMs
* vagrant:reload:                     Reload cluster with updated bootstrap scripts (provision existing VMs)
* vagrant:resize:                     Resize VM resources (requires restart)
* vagrant:restart:                    Restart the cluster (halt + up)
* vagrant:ssh:                        SSH into the control plane node
* vagrant:ssh-worker:                 SSH into a worker node
* vagrant:status:                     Show status of Vagrant VMs and cluster
* vagrant:up:                         Start the Vagrant Kubernetes cluster (optional WORKER_COUNT=N)
* vagrant:wait-ready:                 Wait for Kubernetes cluster to be ready
* validate:cluster:                   Validate cluster connectivity and prerequisites
* validate:manifests:                 Validate all Kubernetes manifests (syntax validation only)
* validate:manifests:cluster:         Validate all Kubernetes manifests against running cluster
