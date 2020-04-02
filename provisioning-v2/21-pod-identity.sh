#!/bin/bash

# If you have a private cluster, make sure you are connecting via jump-box or have VPN connectivity to the vnet

# Make sure that variables are updated
source ./$VAR_FILE

#***** Enable AAD Pod Identity *****
# Docs: https://github.com/Azure/aad-pod-identity

# Pod Identity can be used to allow AKS pods to access Azure resources (like App Gateway, storage,...) without using 
# explicitly username and password. This would make access more secure. 
# This will be happing using normal kubernetes primitives and binding to pods happen seamlessly through
# selectors

# It is worth mentioning that Pod Identity is part of Azure AD Managed Identity platform which covers even more services
# that can leverage this secure way for authentication and authorization.
# Read more  here: https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview

# Run this command to create the aad-pod-identity deployment on our RBAC-enabled cluster:
# This will create the following k8s objects:
# First: NMI (Node Managed Identity) Deamon Set Deployment
# 1. Service Account for NMI
# 2. CRD for AzureAssignedIdentity, AzureIdentityBinding, AzureIdentity, AzureIdentityException
# 3. Cluster Role for NMI
# 4. Cluster Role binding for NMI Service Account
# 5. DeamonSet for NMI controller
# Second: MIC (Managed Identity Controller)
# 1. Service Account for MIC
# 2. Cluster Role for MIC
# 3. Cluster Role binding for MIC Service Account
# 4. Deployment of MIC
# Pods will be running in (default) namespace.

kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
# You will get something like:
# serviceaccount/aad-pod-id-nmi-service-account created
# customresourcedefinition.apiextensions.k8s.io/azureassignedidentities.aadpodidentity.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/azureidentitybindings.aadpodidentity.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/azureidentities.aadpodidentity.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/azurepodidentityexceptions.aadpodidentity.k8s.io created
# clusterrole.rbac.authorization.k8s.io/aad-pod-id-nmi-role created
# clusterrolebinding.rbac.authorization.k8s.io/aad-pod-id-nmi-binding created
# daemonset.apps/nmi created
# serviceaccount/aad-pod-id-mic-service-account created
# clusterrole.rbac.authorization.k8s.io/aad-pod-id-mic-role created
# clusterrolebinding.rbac.authorization.k8s.io/aad-pod-id-mic-binding created
# deployment.apps/mic created

# You should see MIC (deployment)/NMI (daemonset) pods running
kubectl get pods -o wide

# MIC:
# The Managed Identity Controller (MIC) is a Kubernetes custom resource that watches for changes to pods, identities, 
# and bindings through the Kubernetes API server. 

# NMI:
# The Node Managed Identity deamonset identifies the pod based on the remote address of the request and then queries Kubernetes (through MIC) for 
# a matching Azure identity. NMI then makes an Azure Active Directory Authentication Library (ADAL) request to get the token for 
# the client id and returns it as a response. If the request had client id as part of the query, it is validated against the 
# admin-configured client id.

# By default, AAD Pod Identity matches pods to identities across namespaces
# Refer to this guide to allow matching only within the namespace attached to the AzureIdentity resource
# https://github.com/Azure/aad-pod-identity/blob/master/docs/readmes/README.namespaced.md

# DEMO
# Note: You AKS now have the support for Pod Identity, I will be provisioning an Azure Identity for each service when appropriate in the rest of the scripts

# If you want a show case where you are using managed identity now, you can follow the demo in pod-identity-demo.sh script, if not you can skip and apply in a later script

#***** END Enable AAD Pod Identity *****

echo "Pod-Identity Scripts Execution Completed"