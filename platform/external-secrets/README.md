# External Secrets Operator

This directory contains the configuration for External Secrets Operator (ESO), which manages secrets from external sources.

## Architecture

```
┌─────────────────────┐
│  secrets-store      │  ← Secure namespace with actual secret values
│  namespace          │     (Access restricted to ESO)
└──────────┬──────────┘
           │
           │ ESO reads secrets
           ↓
┌──────────────────────┐
│  External Secrets    │  ← Syncs secrets to target namespaces
│  Operator            │
└──────────┬───────────┘
           │
           └─→ Keycloak namespace
```

## Components

### 1. External Secrets Operator
- **File**: `helmrelease.yaml`
- **Purpose**: Kubernetes operator that syncs secrets from external sources
- **Features**: Webhook validation, cert management, security hardening

### 2. Secrets Store Namespace
- **File**: `secrets-namespace.yaml`
- **Purpose**: Secure namespace for storing actual secret values
- **Access**: Restricted to ESO service accounts only

### 3. RBAC Configuration
- **File**: `rbac.yaml`
- **Purpose**: Service accounts and role bindings for ESO
- **Permissions**: Read-only access to secrets in secrets-store namespace

### 4. Network Policy
- **File**: `network-policy.yaml`
- **Purpose**: Allow ESO webhook to function properly
- **Policy**: Allow all traffic in external-secrets namespace

## Secret Management

### Current Setup (Kubernetes Backend)

Secrets are stored in the `secrets-store` namespace and synced to target namespaces:

**Keycloak Secrets:**
- `keycloak-admin` - Admin credentials
- `keycloak-postgresql` - Database credentials

### How It Works

1. **Source Secrets**: Actual values stored in `secrets-store` namespace
2. **SecretStores**: Define how to access source secrets (per namespace)
3. **ExternalSecrets**: Define what secrets to sync and where
4. **Target Secrets**: Synced secrets available in target namespaces

## Usage

### Viewing Secrets Status

```bash
# Check all ExternalSecrets
kubectl get externalsecrets -A

# Check specific ExternalSecret
kubectl get externalsecret keycloak-admin -n keycloak -o yaml

# Check if secrets are synced
kubectl get secrets -n keycloak
```

### Updating Secrets

**To update a secret:**

```bash
# Update the source secret in secrets-store namespace
kubectl edit secret keycloak-admin -n secrets-store

# ESO will automatically sync the change within the refresh interval (1h)
# Or force immediate sync:
kubectl annotate externalsecret keycloak-admin -n keycloak \
  force-sync=$(date +%s) --overwrite
```

### Adding New Secrets

1. **Create source secret** in `secrets-store` namespace:
   ```bash
   kubectl create secret generic my-secret -n secrets-store \
     --from-literal=key=value
   ```

2. **Create ExternalSecret** in target namespace:
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: my-secret
     namespace: my-namespace
   spec:
     refreshInterval: 1h
     secretStoreRef:
       name: secrets-store
       kind: SecretStore
     target:
       name: my-secret
     data:
     - secretKey: key
       remoteRef:
         key: my-secret
         property: key
   ```

## Production Recommendations

### Migrate to Cloud Secret Manager

For production, consider migrating to a cloud-based secret manager:

**AWS Secrets Manager:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
```

**Azure Key Vault:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
spec:
  provider:
    azurekv:
      vaultUrl: "https://my-vault.vault.azure.net"
      authType: ServicePrincipal
```

**HashiCorp Vault:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
```

### Enable Secret Rotation

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rotated-secret
spec:
  refreshInterval: 15m  # Check for changes every 15 minutes
  # ... rest of config
```

### Secret Encryption at Rest

Ensure Kubernetes encrypts secrets at rest:

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-secret>
```

## Troubleshooting

### ExternalSecret not syncing

```bash
# Check ExternalSecret status
kubectl describe externalsecret <name> -n <namespace>

# Check ESO logs
kubectl logs -n external-secrets deployment/external-secrets

# Force sync
kubectl annotate externalsecret <name> -n <namespace> \
  force-sync=$(date +%s) --overwrite
```

### Webhook errors

```bash
# Check webhook pod
kubectl get pods -n external-secrets

# Check webhook logs
kubectl logs -n external-secrets deployment/external-secrets-webhook

# Temporarily delete webhook for emergency fixes
kubectl delete validatingwebhookconfiguration externalsecret-validate
```

## Security Best Practices

1. **Restrict Access**: Only ESO service accounts should access `secrets-store` namespace
2. **Audit Logging**: Enable audit logs for secret access
3. **Rotation**: Implement regular secret rotation
4. **Encryption**: Enable encryption at rest for Kubernetes secrets
5. **Monitoring**: Alert on failed secret syncs

## References

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)
