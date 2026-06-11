# Argo CD Example

A simple kustomization deployment using kustomize referenced by the Getting Started with OpenShift GitOps blog coming soon.

```bash

# List all Argo CD applications managed within the OpenShift GitOps namespace.
oc -n "${REDHAT_GITOPTS_NAMESPACE}" get applications

# Delete the Argo CD application named odm from the OpenShift GitOps namespace.
oc -n "${REDHAT_GITOPTS_NAMESPACE}" delete application odm

# Delete the odm-sno-uat namespace and all resources contained within it.
# oc delete namespace odm-sno-uat
delete_project --odm

# Create the odm-sno-uat project (namespace) for deploying application resources.
create_project -n "odm-sno-uat" --docker

oc apply -f "namespace.yaml"


# Both commands effectively grant Argo CD admin permissions in the namespace
# Grant the Argo CD application controller service account the admin role in the odm-sno-uat namespace using the OpenShift policy helper command.
oc -n odm-sno-uat adm policy add-role-to-user admin "system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller"

# Explicitly create a RoleBinding that grants the Argo CD application controller service account the admin ClusterRole in the odm-sno-uat namespace.
oc -n odm-sno-uat create rolebinding argocd-bgd-admin --clusterrole=admin --serviceaccount=openshift-gitops:openshift-gitops-argocd-application-controller

#
# oc -n "${REDHAT_GITOPTS_NAMESPACE}" get applications
# oc -n "${REDHAT_GITOPTS_NAMESPACE}" delete application odm
#

```
