# Jenkins Deployment with ArgoCD

This directory contains the Kubernetes manifests to deploy a Jenkins controller. This application is designed to be deployed and managed by ArgoCD.

## Prerequisites

-   **ArgoCD:** Must be installed and running in your cluster.
-   **Cert-Manager:** Must be installed and configured to issue certificates, as required by `cert.yaml`.
-   **Persistent Storage:** Your cluster must have a default `StorageClass` available for the Jenkins home directory `PersistentVolumeClaim`.
-   **Ingress Controller:** An Ingress or Gateway controller must be running to expose the Jenkins UI.

## Deployment via ArgoCD

To deploy Jenkins, you will create an ArgoCD `Application` manifest that points to this directory in your Git repository. ArgoCD will then automatically sync the manifests and manage the Jenkins deployment.

### Example ArgoCD Application Manifest

Create a file named `jenkins-application.yaml` with the following content:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jenkins
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'YOUR_GIT_REPO_URL'  # <-- Replace with your Git repository URL
    path: jenkins
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: jenkins
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Replace `YOUR_GIT_REPO_URL` with the URL of your Git repository.**

### Apply the Application Manifest

Apply the manifest to your cluster. ArgoCD will detect it and start the deployment process.

```bash
kubectl apply -f jenkins-application.yaml
```

## Accessing Jenkins

Once deployed, Jenkins will be accessible at the hostname specified in the Ingress object within `jenkins.yaml` (e.g., `jenkins.your-domain.com`).

To get the initial administrator password, exec into the Jenkins pod and view the contents of the specified file:

```bash
kubectl exec -n jenkins <jenkins-pod-name> -- cat /var/jenkins_home/secrets/initialAdminPassword
```

## Manifests

-   `jenkins.yaml`: Contains the `Deployment`, `Service`, `PersistentVolumeClaim`, and `Ingress` for the Jenkins controller.
-   `cert.yaml`: The `Certificate` resource for securing the Jenkins UI with a TLS certificate.
