# Keycloak Realm Configuration with OpenTofu

This directory contains OpenTofu scripts to declaratively manage realms, clients, roles, and users within a running Keycloak instance. This allows you to treat your Keycloak configuration as code, ensuring it is version-controlled and repeatable.

This configuration is designed to be run **after** Keycloak has been deployed to the Kubernetes cluster.

## Prerequisites

-   **OpenTofu:** You must have `opentofu` installed. These scripts are written for OpenTofu, the open-source fork of Terraform.
-   **Keycloak Instance:** A running Keycloak instance accessible from where you are running the `tofu` commands.
-   **Keycloak Provider Credentials:** You need the Keycloak URL and admin credentials. These are configured in the `terraform.tfvars` file.

## Configuration Overview

-   `main.tf`: Defines all the Keycloak resources to be created, such as realms, clients, roles, and users.
-   `variable.tf`: Declares the input variables used in the configuration (e.g., credentials, URLs).
-   `output.tf`: Defines the output values that will be displayed after applying the configuration, such as client secrets.
-   `terraform.tfvars`: **(Important)** This is where you must provide your specific values for the variables, such as the Keycloak admin password and URL.
-   `secret.sh`: A helper script to automate the creation of Kubernetes secrets from the OpenTofu outputs. This is useful for injecting client secrets into other applications like Grafana.

## Deployment Steps

### 1. Configure Variables

Before running OpenTofu, you must fill in the required values in the `terraform.tfvars` file. This file is intentionally ignored by Git to prevent committing secrets.

```hcl
# terraform.tfvars

keycloak_url      = "https://keycloak.your-domain.com" # Replace with your Keycloak URL
keycloak_user     = "admin"
keycloak_password = "your-admin-password"      # Replace with your admin password
```

### 2. Initialize OpenTofu

Navigate to this directory and run the `init` command. This will download the required Keycloak provider plugin.

```bash
opentofu init
```

### 3. Plan the Changes

Run the `plan` command to see what changes OpenTofu will make to your Keycloak instance. This is a dry run and is safe to execute.

```bash
opentofu plan
```

### 4. Apply the Configuration

If the plan looks correct, apply the changes to configure Keycloak.

```bash
opentofu apply --auto-approve
```

### 5. Create Kubernetes Secrets (Optional)

After applying the configuration, OpenTofu will output sensitive data like client secrets. The `secret.sh` script is designed to take these outputs and create the necessary Kubernetes secrets for other applications.

Make sure the script is executable and run it:

```bash
chmod +x secret.sh
./secret.sh
```

This script uses the `tofu output` command to fetch the required values and `kubectl` to create the secrets in the appropriate namespaces.
