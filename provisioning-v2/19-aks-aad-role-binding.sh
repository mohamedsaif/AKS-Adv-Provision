#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

#***** Basic AAD Role Binding Configuration *****

# NOTE: Execute the blow steps ONLY if you successfully completed the AAD provisioning 
# Grape the new cluster ADMIN credentials
# the AKS cluster with AAD enabled
# Objective here to grant your AAD account an admin access to the AKS cluster
az aks get-credentials --resource-group $RG_AKS  --name $AKS_CLUSTER_NAME --admin

#List our currently available contexts
kubectl config get-contexts

#set our current context to the AKS admin context (by default not needed as get-credentials set the active context)
kubectl config use-context $AKS_CLUSTER_NAME-admin

#Check the cluster status through kubectl
kubectl get nodes

# Access Kubernetes Dashboard. You should have a lot of forbidden messages
# this would be due to that you are accessing the dashboard with a kubernetes-dashboard service account
# which by default don't have access to the cluster
az aks browse --resource-group $RG_AKS  --name $AKS_CLUSTER_NAME

# Before you can use AAD account with AKS, a role or cluster role binding is needed.
# Let's grant the current logged user access to AKS via its User Principal Name (UPN)
# Have a look at the UPN for the signed in account
az ad signed-in-user show --query userPrincipalName -o tsv

# Use Object Id if the user is in external directory (like guest account on the directory)
SIGNED_USER=$(az ad signed-in-user show --query objectId -o tsv)

# Copy either the objectId to aad-user-cluster-admin-binding.yaml file before applying the deployment
sed ./deployments/aad-user-cluster-admin-binding.yaml \
    -e s/USEROBJECTID/$SIGNED_USER/g \
    > ./deployments/aad-user-cluster-admin-binding-updated.yaml
# Now granting the signed in account a cluster admin rights
kubectl apply -f ./deployments/aad-user-cluster-admin-binding-updated.yaml

# We will try to get the credentials for the current logged user (without the --admin flag)
az aks get-credentials --resource-group $RG_AKS  --name $AKS_CLUSTER_NAME

#List our currently available contexts. You should see a context without the -admin name
kubectl config get-contexts

#set our current context to the AKS admin context (by default not needed as get-credentials set the active context)
kubectl config use-context $AKS_CLUSTER_NAME

# try out the new context access :). You should notice the AAD login experience with a link and code to be entered in external browser. 
# You should be able to get the nodes after successful authentication
kubectl get nodes

# Great article about Kubernetes RBAC policies and setup https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/

#***** END Basic AAD Role Binding Configuration *****

#***** AAD and AKS RBAC Advanced Configuration *****

# Documentation https://docs.microsoft.com/en-us/azure/aks/azure-ad-rbac
# NOTE: You can leverage the below steps only if you successfully provided AAD enabled AKS cluster

# We will be creating 2 roles: (appdev) group with a user called aksdev1, 
# (opssre) with user akssre1 (SRE: Site Reliability Engineer)
# Note: In production environments, you can use existing users and groups within an Azure AD tenant.

# We will need the AKS resource id during the provisioning
AKS_ID=$(az aks show \
    --resource-group $RG_AKS  \
    --name $AKS_CLUSTER_NAME \
    --query id -o tsv)

# Create the "appdev" group. Sometime you need to wait for a few seconds for the new group to be fully available for the next steps
APPDEV_ID=$(az ad group create \
    --display-name appdev \
    --mail-nickname appdev \
    --query objectId -o tsv)

# Create Azure role assignment for appdev group, this will allow members to access AKS via kubectl
az role assignment create \
  --assignee $APPDEV_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $AKS_ID

# Now creating the opssre group
OPSSRE_ID=$(az ad group create \
    --display-name opssre \
    --mail-nickname opssre \
    --query objectId -o tsv)

# Assigning the group to role on the AKS cluster
az role assignment create \
  --assignee $OPSSRE_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $AKS_ID

exit 0

# Creating our developer user account
AKSDEV1_ID=$(az ad user create \
  --display-name "AKS Dev 1" \
  --user-principal-name aksdev1@mobivisions.com \
  --password P@ssw0rd1 \
  --query objectId -o tsv)

# Adding the new user to the appdev group
az ad group member add --group appdev --member-id $AKSDEV1_ID

# Create a user for the SRE role
AKSSRE1_ID=$(az ad user create \
  --display-name "AKS SRE 1" \
  --user-principal-name akssre1@mobivisions.com \
  --password P@ssw0rd1 \
  --query objectId -o tsv)

# Add the user to the opssre Azure AD group
az ad group member add --group opssre --member-id $AKSSRE1_ID

# Create AKS cluster resources for appdev group
# Make sure that you on the cluster admin context to execute the following commands. You can make sure that active context has -admin in it.
kubectl config use-context $AKS_CLUSTER_NAME-admin

# We will be using namespace isolation. We will create a dev namespace for the developers to use
kubectl create namespace dev

# In Kubernetes, Roles define the permissions to grant, and RoleBindings apply them to desired users or groups. 
# These assignments can be applied to a given namespace, or across the entire cluster.
# So first we will create a Role with full access to dev namespace through applying the manifest role-dev-namespace.yaml
kubectl apply -f ./deployments/role-dev-namespace.yaml

# We need the group resource ID for appdev group to be replaced in the role binding deployment file
az ad group show --group appdev --query objectId -o tsv

# Replace the group id in rolebinding-dev-namespace.yaml before applying the deployment
sed -i rolebinding-dev-namespace.yaml -e "s/groupObjectId/$APPDEV_ID/g"
kubectl apply -f ./deployments/rolebinding-dev-namespace.yaml

# Doing the same to create access for the SRE
kubectl create namespace sre

kubectl apply -f ./deployments/role-sre-namespace.yaml

az ad group show --group opssre --query objectId -o tsv

# Update the opssre group id to rolebinding-sre-namespace.yaml before applying the deployment
sed -i rolebinding-sre-namespace.yaml -e "s/groupObjectId/$OPSSRE_ID/g"
kubectl apply -f ./deployments/rolebinding-sre-namespace.yaml

# Testing now can be done by switching outside of the context of the admin to one of the users created

# Reset the credentials for AKS so you will sign in with the dev user
az aks get-credentials --resource-group $RG_AKS  --name $AKS_CLUSTER_NAME --overwrite-existing

# Now lets try to get nodes. You should have the AAD sign in experience. After signing in with Dev user, you should see it is forbidden :)
kubectl get nodes

# Lets try run a basic NGINX pod on the dev namespace (in case you signed in with a dev user)
kubectl run --generator=run-pod/v1 nginx-dev --image=nginx --namespace dev

# The above command should say: pod/nginx-dev created. Let's see if it is running
kubectl get pods --namespace dev

# Another test is to try to get pods from all namespaces (you should get forbidden again :)
kubectl get pods --all-namespaces
# Error from server (Forbidden): pods is forbidden: User "YOURDEVUSER@TENANT.COM" cannot list resource "pods" in 
# API group "" at the cluster scope

# One final test to schedule a pod in a different namespace (sre for example)
kubectl run --generator=run-pod/v1 nginx-dev --image=nginx --namespace sre
# Error from server (Forbidden): pods is forbidden: User "YOURDEVUSER@TENANT.COM" cannot create resource "pods" in 
# API group "" in the namespace "sre"

# More information about authentication and authorization here https://docs.microsoft.com/en-us/azure/aks/operator-best-practices-identity

# Let's clean up after ourselves

# Get the admin kubeconfig context to delete the necessary cluster resources
kubectl config use-context $AKS_CLUSTER_NAME-admin
# Or use this if you don't have the admin context from the previous steps
az aks get-credentials --resource-group $RG_AKS  --name $AKS_CLUSTER_NAME --admin

# You can delete only the pods and let the users, groups, namespaces intact or delete everything
kubectl delete pod nginx-dev --namespace dev

# Delete the dev and sre namespaces. This also deletes the pods, Roles, and RoleBindings
kubectl delete namespace dev
kubectl delete namespace sre

# Delete the Azure AD user accounts for aksdev and akssre
az ad user delete --upn-or-object-id $AKSDEV1_ID
az ad user delete --upn-or-object-id $AKSSRE1_ID

# Delete the Azure AD groups for appdev and opssre. This also deletes the Azure role assignments.
az ad group delete --group appdev
az ad group delete --group opssre

#***** END AAD and AKS RBAC Advanced Configuration *****

#***** Configure AKS Dashboard Access with AAD *****

# NOTE: You can leverage the below steps only if you successfully provided AAD enabled AKS cluster

# Create the "aks-dashboard-admins" group. Sometime you need to wait for a few seconds for the new group to be fully available for the next steps
DASHBOARD_ADMINS_ID=$(az ad group create \
    --display-name AKS-Dashboard-Admins \
    --mail-nickname aks-dashboard-admins \
    --query objectId -o tsv)

# Create Azure role assignment for the group, this will allow members to access AKS via kubectl, dashboard
az role assignment create \
  --assignee $DASHBOARD_ADMINS_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $AKS_ID

# We will add the current logged in user to the dashboard admins group
# Get the UPN for a user in the same AAD directory
SIGNED_USER_UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv)

# Use Object Id if the user is in external directory (like guest account on the directory)
SIGNED_USER_UPN=$(az ad signed-in-user show --query objectId -o tsv)

# Add the user to dashboard group
az ad group member add --group $DASHBOARD_ADMINS_ID --member-id $SIGNED_USER_UPN

# Create role and role binding for the new group (after replacing the AADGroupID)
sed -i dashboard-proxy-binding.yaml -e "s/AADGroupID/$DASHBOARD_ADMINS_ID/g"
kubectl apply -f ./deployments/dashboard-proxy-binding.yaml

# As a workaround accessing the dashboard using a token without enforcing https secure communication (tunnel is exposed ver http), 
# you can edit the dashboard deployment with adding the following argument
# It is an issue currently being discussed here https://github.com/MicrosoftDocs/azure-docs/issues/23789
# args: ["--authentication-mode=token", "--enable-insecure-login"] under spec: containers
# spec:
#   containers:
#   - name: *****
#     image: *****
#     args: ["--authentication-mode=token", "--enable-insecure-login"]
kubectl edit deploy -n kube-system kubernetes-dashboard

# Get AAD token for the signed in user (given that user has the appropriate access). Use (az login) if you are not signed in
SIGNED_USER_TOKEN=$(az account get-access-token --query accessToken -o tsv)
echo $SIGNED_USER_TOKEN

# establish a tunnel and login via token above
# If AAD enabled, you should see the AAD sign in experience with a link and a code to https://microsoft.com/devicelogin
az aks browse --resource-group $RG_AKS --name $AKS_CLUSTER_NAME

# You can also use kubectl proxy to establish the tunnel as well
# kubectl proxy
# Then you can navigate to sign in is located http://localhost:8001/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy/#!/login

# Note: you can also use the same process but with generated kubeconfig file for a Service Account that is bound to a specific namespace 
# to login to the dashboard.

#***** END Configure AKS Dashboard Access with AAD *****

echo "AKS-Post-Provision Scripts Execution Completed"
