#!/bin/bash

# If you have a private cluster, make sure you are connecting via jump-box or have VPN connectivity to the vnet

# Make sure that variables are updated
source ./$VAR_FILE

# DEMO
# Note: You AKS now have the support for Pod Identity, I will be provisioning an Azure Identity for each service when appropriate in the rest of the scripts

# If you want a show case where you are using managed identity now, you can follow the below demo, if not you can skip and apply in a later script

# To show case how pod identity can be used, we will create new MSI account, add it to the the cluster then
# assigned it to pods with a selector through a (aadpodidbinding) label matching it (which we will do later)
# We will be using "User-Assigned Managed Identity" which is a stand alone Managed Service Identity (MSI) that 
# can be reused across multiple resources.
# Note we are getting the clientId, id and principalId
IDENTITY_NAME="${PREFIX}-pods-default-identity"
MANAGED_IDENTITY=$(az identity create -g $RG_AKS -n $IDENTITY_NAME)
# You can load the MSI of an existing one as well if you lost session or you have already one
# MANAGED_IDENTITY=$(az identity show -g $RG_AKS -n $IDENTITY_NAME)
echo $MANAGED_IDENTITY | jq
MANAGED_IDENTITY_CLIENTID=$(echo $MANAGED_IDENTITY | jq .clientId | tr -d '"')
echo $MANAGED_IDENTITY_CLIENTID
MANAGED_IDENTITY_ID=$(echo $MANAGED_IDENTITY | jq .id | tr -d '"')
echo $MANAGED_IDENTITY_ID
MANAGED_IDENTITY_SP_ID=$(echo $MANAGED_IDENTITY | jq .principalId | tr -d '"')
echo $MANAGED_IDENTITY_SP_ID

# Saving the MSI for later use
echo export MANAGED_IDENTITY_CLIENTID=$MANAGED_IDENTITY_CLIENTID >> ./$VAR_FILE
echo export MANAGED_IDENTITY_ID=$MANAGED_IDENTITY_ID >> ./$VAR_FILE
echo export MANAGED_IDENTITY_SP_ID=$MANAGED_IDENTITY_SP_ID >> ./$VAR_FILE

# Binding the new Azure Identity to AKS
# Replace the place holders with values we got the created managed identity
# I'm creating a new file so to maintain the generic nature of the file for repeated deployment
sed ./deployments/aad-pod-identity.yaml \
    -e s/NAME/$IDENTITY_NAME/g \
    -e 's@RESOURCE_ID@'"${MANAGED_IDENTITY_ID}"'@g' \
    -e s/CLIENT_ID/$MANAGED_IDENTITY_CLIENTID/g \
    > aad-pod-identity-updated.yaml

# Current deployment file uses type (0) which is for user assigned managed identity, which what we created. use (1) for SP
kubectl apply -f aad-pod-identity-updated.yaml

# Installing Azure Identity Binding
IDENTITY_BINDING_NAME="${PREFIX}-aad-identity-binding"
POD_SELECTOR="aad_enabled_pod"
sed ./deployments/aad-pod-identity-binding.yaml \
    -e s/NAME/$IDENTITY_NAME/g \
    -e 's@AAD_IDENTITY@'"${IDENTITY_NAME}"'@g' \
    -e s/AAD_SELECTOR/$POD_SELECTOR/g \
    > aad-pod-identity-binding-updated.yaml

kubectl apply -f aad-pod-identity-binding-updated.yaml

# The above binding will only applies with pods with label: aadpodidbinding=aad_enabled_pod
# NAME       READY     STATUS    RESTARTS   AGE       LABELS
# someapp   1/1       Running   10         10h       aadpodidbinding=aad_enabled_pod,app=someapp

# Now we set permission for Managed Identity Controller (MIC) for the user assigned identities 
# Because we deployed the Azure Identity outside the automatically created resource 
# group (has by default the name of MC_${RG}_${AKSNAME}_${LOC}) unless you specified otherwise
# we need to assign Managed Identity Operator role to the the AKS cluster service principal (so it can managed it)
AKS_SP_ID=$(az aks show \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --query servicePrincipalProfile.clientId -o tsv)
MIC_ASSIGNMENT=$(az role assignment create --role "Managed Identity Operator" --assignee $AKS_SP_ID --scope $MANAGED_IDENTITY_ID)
echo $MIC_ASSIGNMENT | jq

# Next steps is to have Azure roles/permissions assigned to the user assigned managed identity and map it to pods.
# For example, you can allow MSI to have reader access on the cluster resource group 
# (like /subscriptions/<subscriptionid>/resourcegroups/<resourcegroup>)
RG_ID=$(az group show --name $RG_AKS --query id -o tsv)
echo $RG_ID
az role assignment create --role Reader --assignee $MANAGED_IDENTITY_SP_ID --scope $RG_ID
# This to get the auto generated MC_ resource group for AKS cluster nodes
RG_NODE_NAME=$(az aks show \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --query nodeResourceGroup -o tsv)
RG_NODE_ID=$(az group show --name $RG_NODE_NAME --query id -o tsv)
echo $RG_NODE_ID
az role assignment create --role Reader --assignee $MANAGED_IDENTITY_SP_ID --scope $RG_NODE_ID

# By doing the same, you can assign different supported Azure resources to the MSI which then through MIC can be assigned to 
# pods via label selectors.
# Specifically, when a pod is scheduled, the MIC assigns an identity to the underlying VM during the creation phase. 
# When the pod is deleted, it removes the assigned identity from the VM. 
# The MIC takes similar actions when identities or bindings are created or deleted.
# Sample deployment will look like:
# apiVersion: extensions/v1beta1
# kind: Deployment
# metadata:
#   labels:
#     app: demo
#     aadpodidbinding: aad_enabled_pod
#   name: demo
#   namespace: dev
# spec:
#   **********

# One other key use is with App Gateway (incase if using it as ingress controller) by assigning MSI contributor role on the App Gateway

# Read more in the documentation: https://github.com/Azure/aad-pod-identity
# General documentation about Azure Managed Identities 
# https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview

#***** END Enable AAD Pod Identity *****

echo "Pod-Identity Scripts Execution Completed"