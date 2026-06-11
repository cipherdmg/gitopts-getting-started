# IBM ODM GitOps Deployment with ArgoCD

This repository contains the GitOps configuration for deploying IBM Operational Decision Manager (ODM) on OpenShift using ArgoCD (OpenShift GitOps operator).

## Repository Structure

```
.
├── applications/
│   └── odm-uat-application.yaml    # ArgoCD Application manifest
├── helm/
│   └── ibm-odm-prod-25.1.10.tgz   # IBM ODM Helm chart
├── values/
│   └── odm-sno-uat.yaml           # Helm values for UAT environment
└── overlays/
    └── uat/
        ├── kustomization.yaml                  # Kustomize configuration
        ├── odm-sno-uat-ds-auth-sso.yaml       # Authentication secret (sync wave -1)
        └── odm-sno-uat-ds-cert.yaml           # TLS certificate secret (sync wave -1)
```

## How It Works

### ArgoCD + Helm + Kustomize Integration

**Answer to your question: Should you store Helm output or just values?**

✅ **Store only the Helm chart and values file** (which you already have)
❌ **Do NOT store rendered Helm output in Git**

**Why?** ArgoCD natively supports Helm charts and will:
1. Render the Helm chart using your values file
2. Apply Kustomize patches on top of the rendered output
3. Deploy everything to your cluster

This approach gives you:
- Clean Git history (no large rendered YAML files)
- Easy values management
- Ability to patch Helm output with Kustomize
- Proper secret ordering with sync waves

### Deployment Order (Sync Waves)

ArgoCD uses sync waves to control deployment order:

1. **Wave -1**: Secrets are created first
   - `odm-sno-uat-ds-auth-sso.yaml` (authentication config)
   - `odm-sno-uat-ds-cert.yaml` (TLS certificates)

2. **Wave 0** (default): Helm chart deployment
   - ArgoCD renders the Helm chart with your values
   - Kustomize patches are applied
   - ODM components are deployed

This ensures secrets exist before the Helm chart tries to reference them.

## Prerequisites

1. OpenShift cluster with GitOps operator installed
2. Access to IBM Container Registry (`cp.icr.io`)
3. Namespace `odm-uat` (created automatically by ArgoCD)

## Setup Instructions

### 1. Update Secrets (IMPORTANT!)

Before deploying, you must update the placeholder secrets with real values:

#### Authentication Secret
The `odm-sno-uat-ds-auth-sso.yaml` already contains your base64-encoded webSecurity.xml configuration.

#### TLS Certificate Secret
Replace the placeholder in `overlays/uat/odm-sno-uat-ds-cert.yaml`:

```bash
# Generate self-signed certificate (for testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=odm-uat.apps.your-cluster.com"

# Base64 encode (Linux/Mac)
cat tls.crt | base64 -w 0
cat tls.key | base64 -w 0

# Base64 encode (Windows PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("tls.crt"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("tls.key"))
```

Update the `tls.crt` and `tls.key` values in the secret file.

### 2. Configure Image Pull Secret (if needed)

If you need credentials for `cp.icr.io`, add to `values/odm-sno-uat.yaml`:

```yaml
image:
  pullSecrets:
    - ibm-entitlement-key
```

Then create the secret in the `odm-uat` namespace:

```bash
oc create secret docker-registry ibm-entitlement-key \
  --docker-server=cp.icr.io \
  --docker-username=cp \
  --docker-password=YOUR_ENTITLEMENT_KEY \
  -n odm-uat
```

### 3. Deploy the ArgoCD Application

```bash
# Apply the ArgoCD Application
oc apply -f applications/odm-uat-application.yaml

# Watch the deployment
oc get application odm-uat -n openshift-gitops -w

# Or use ArgoCD UI
# Navigate to: https://openshift-gitops-server-openshift-gitops.apps.your-cluster.com
```

### 4. Access ArgoCD UI

```bash
# Get ArgoCD admin password
oc get secret openshift-gitops-cluster -n openshift-gitops \
  -o jsonpath='{.data.admin\.password}' | base64 -d

# Get ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops \
  -o jsonpath='{.spec.host}'
```

## Configuration Details

### Sync Policy

The ArgoCD application is configured with:
- ✅ **Auto-sync**: Automatically deploys changes from Git
- ✅ **Self-heal**: Corrects manual changes in the cluster
- ❌ **Auto-prune**: Disabled (manual cleanup required for safety)
- ✅ **Create namespace**: Automatically creates `odm-uat` namespace

### Kustomize + Helm Integration

The `overlays/uat/kustomization.yaml` file:
1. References the Helm chart in the `helm/` directory
2. Uses values from `values/odm-sno-uat.yaml`
3. Includes secrets as resources (deployed first via sync waves)
4. Applies patches to the rendered Helm output (e.g., probe modifications)

### Current Patches

The kustomization applies patches to Decision Server Runtime deployments:
- Increases termination grace period to 90s
- Modifies liveness/readiness/startup probes to use `curl` with TLS certificates
- Ensures proper graceful shutdown

## Troubleshooting

### Check Application Status
```bash
oc get application odm-uat -n openshift-gitops
oc describe application odm-uat -n openshift-gitops
```

### Check Sync Status
```bash
# Via CLI
argocd app get odm-uat

# Or check in ArgoCD UI for detailed sync status
```

### Check Deployed Resources
```bash
oc get all -n odm-uat
oc get secrets -n odm-uat
```

### Common Issues

1. **Secrets not found**: Ensure sync waves are set correctly (wave -1 for secrets)
2. **Image pull errors**: Verify image pull secrets are configured
3. **Helm rendering errors**: Check that the Helm chart path and values file are correct
4. **Sync failures**: Review ArgoCD application events and logs

## Modifying the Deployment

### Update ODM Configuration
1. Edit `values/odm-sno-uat.yaml`
2. Commit and push to Git
3. ArgoCD will automatically sync (if auto-sync is enabled)

### Add More Patches
1. Edit `overlays/uat/kustomization.yaml`
2. Add new patches under the `patches:` section
3. Commit and push

### Change Sync Policy
Edit `applications/odm-uat-application.yaml` and modify the `syncPolicy` section.

## Security Notes

⚠️ **Important**: The secrets in this repository contain sensitive data:
- Consider using sealed-secrets or external secret management
- Rotate credentials regularly
- Use proper RBAC to restrict access to this repository

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenShift GitOps](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
- [IBM ODM Documentation](https://www.ibm.com/docs/en/odm/9.5.0)
- [Kustomize with Helm](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_helmchartinflationgenerator_)
