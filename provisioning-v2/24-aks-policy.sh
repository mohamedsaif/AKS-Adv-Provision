#!/bin/bash

# Make sure that variables are updated
source ./aks.vars

### AKS Policy via Azure Policy (Preview)
# Docs: https://docs.microsoft.com/en-us/azure/governance/policy/concepts/rego-for-aks
# you must complete the registration of the service mentioned earlier before executing this command
az aks enable-addons --addons azure-policy --name $AKS_CLUSTER_NAME --resource-group $RG

echo "AKS-Policy Scripts Execution Completed"