# Certificate Deletion Protection

## Overview

All Certificate resources in the cluster are protected from automatic deletion by a Kyverno ClusterPolicy. This ensures that certificates, which are critical for TLS security, cannot be accidentally deleted by controllers, cleanup jobs, or automated processes.

## Policy Details

- **Policy Name**: `protect-certificates`
- **Enforcement**: Enforced (blocks all deletions without annotation)
- **Scope**: All Certificate resources in all namespaces

## How It Works

The policy blocks all DELETE operations on Certificate resources unless the certificate has the explicit annotation:
```
cert-manager.io/allow-deletion: "true"
```

## Manual Deletion Process

To manually delete a certificate (when intentionally needed):

### Step 1: Add the Allow Deletion Annotation

```bash
kubectl annotate certificate <certificate-name> -n <namespace> cert-manager.io/allow-deletion=true
```

### Step 2: Delete the Certificate

```bash
kubectl delete certificate <certificate-name> -n <namespace>
```

### Example

```bash
# Add annotation to allow deletion
kubectl annotate certificate grafana-cert -n monitoring cert-manager.io/allow-deletion=true

# Delete the certificate
kubectl delete certificate grafana-cert -n monitoring
```

## Important Notes

1. **Automatic Deletions Are Blocked**: Any attempt to delete a certificate without the annotation will be rejected by the admission webhook.

2. **Manual Deletion Only**: This policy ensures that only intentional, manual deletions are allowed. Controllers, cleanup policies, and automated processes cannot delete certificates.

3. **Re-creation**: After deletion, if the certificate is managed by GitOps (Flux), it will be recreated automatically from the Git repository.

4. **Security**: This protection prevents accidental certificate deletion which could cause service outages or security issues.

## Verification

To verify the policy is active:

```bash
# Check policy status
kubectl get clusterpolicy protect-certificates

# Test deletion (should be blocked)
kubectl delete certificate <certificate-name> -n <namespace>
# Expected: Error from server: admission webhook denied the request
```

## Policy Configuration

The policy is defined in:
- `platform/kyverno/policies/certificate-protection-policy.yaml`
- Managed by Flux kustomization: `kyverno-policies`

