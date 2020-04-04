#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

### AKS Policy via Azure Policy (Preview)

# Making sure all resource providers are registered
# Log in first with az login if you're not using Cloud Shell

# Provider register: Register the Azure Kubernetes Services provider
az provider register --namespace Microsoft.ContainerService

# Provider register: Register the Azure Policy provider
az provider register --namespace Microsoft.PolicyInsights

# Feature register: enables installing the add-on
az feature register --namespace Microsoft.ContainerService --name AKS-AzurePolicyAutoApprove

# Use the following to confirm the feature has registered
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKS-AzurePolicyAutoApprove')].{Name:name,State:properties.state}"

# Once the above shows 'Registered' run the following to propagate the update
az provider register -n Microsoft.ContainerService

# Feature register: enables the add-on to call the Azure Policy resource provider
az feature register --namespace Microsoft.PolicyInsights --name AKS-DataPlaneAutoApprove

# Use the following to confirm the feature has registered
az feature list -o table --query "[?contains(name, 'Microsoft.PolicyInsights/AKS-DataPlaneAutoApprove')].{Name:name,State:properties.state}"

# Once the above shows 'Registered' run the following to propagate the update
az provider register -n Microsoft.PolicyInsights

# Making sure AKS preview flag is registered
az extension add --name aks-preview

# Validate the version of the preview extension (0.4 < is required)
az extension show --name aks-preview --query [version]

# If you need update
# az extension update --name aks-preview

# Docs: https://docs.microsoft.com/en-us/azure/governance/policy/concepts/rego-for-aks
# you must complete the registration of the service mentioned earlier before executing this command
az aks enable-addons --addons azure-policy --name $AKS_CLUSTER_NAME --resource-group $RG_AKS

echo "AKS-Policy Scripts Execution Completed"