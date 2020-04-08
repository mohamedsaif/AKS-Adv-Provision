#!/bin/bash

# Important: Enabling preview features of AKS takes effect at the subscription level. I advise that you enable these only on non-production subscription as
# it may alter the default behavior of some of the CLI commands and/or services in scope

echo "No configured preview features currently enabled!"
echo "Please uncomment the required features as needed."

# Enable aks preview features (like autoscaler) through aks-preview Azure CLI extension
# az extension add --name aks-preview

# If you already enabled the aks-preview extension before, make sure you are using the latest version
# If the version is not per the required features, execute update instead of add
# At the time of writing this, version was 0.4.17
# az extension update --name aks-preview

# Register Windows Containers preview features which will allow creating a Node Pool that will run windows containers in your AKS cluster
# Read more about the features and limitations here: https://docs.microsoft.com/en-us/azure/aks/windows-container-cli
# az feature register --name WindowsPreview --namespace Microsoft.ContainerService

# Enabling Azure Policy for AKS
# Docs: https://docs.microsoft.com/en-us/azure/governance/policy/concepts/rego-for-aks
# Register the Azure Policy provider
# az provider register --namespace Microsoft.PolicyInsights
# Enables installing the add-on
# az feature register --namespace Microsoft.ContainerService --name AKS-AzurePolicyAutoApprove
# Enables the add-on to call the Azure Policy resource provider
# az feature register --namespace Microsoft.PolicyInsights --name AKS-DataplaneAutoApprove
# Once the above shows 'Registered' run the following to propagate the update
# az provider register -n Microsoft.PolicyInsights

# As the new resource provider takes time (several mins) to register, you can check the status here. Wait for the state to show "Registered"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/WindowsPreview')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKS-AzurePolicyAutoApprove')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.PolicyInsights/AKS-DataPlaneAutoApprove')].{Name:name,State:properties.state}"

# After registrations finish with status "Registered", you can update the provider
az provider register --namespace Microsoft.ContainerService

echo "Preview Providers Registration Completed"