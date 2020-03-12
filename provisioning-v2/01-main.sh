#!/bin/bash

# Primary script to orchestrate end-to-end execution

# Switch to provisioning-v2 folder
cd provisioning-v2

# Marking the script files to be executable
chmod -R +x .


# Variables
# Double check the variables script before execution (you might need to replace some values)
./02-variables.sh
# Reload to make sure everything is updated in the current session
source ./aks.vars
# You can save this variables file so it can be used later
# Check the variables (it might be long :)
export

# Login
source ./aks.vars
./03-login.sh

# Preview Providers
# Please review before execution
source ./aks.vars
./04-preview-providers.sh

# Tags setup
# Please review before execution
# You need to run it once per subscription
./05-tags.sh

# Resource Groups
source ./aks.vars
./06-resource-groups.sh

# Monitoring (be patient.. it might take couple of mins)
source ./aks.vars
./07-monitoring.sh

# Azure Key Vault
source ./aks.vars
./08-key-vault.sh

# Virtual Network
source ./aks.vars
./09-virtual-network.sh

# Application Gateway
source ./aks.vars
./10-app-gateway.sh

# Jump-box and DevOps agent
source ./aks.vars
./11-jump-box.sh

# API Management Service (APIM)
source ./aks.vars
./12-apim.sh

# Container Registry (ACR)
source ./aks.vars
./13-container-registry.sh

# AKS outbound PIP
source ./aks.vars
./14-aks-pip.sh

# AKS Service Principal
# Service principal can be reused if you needed to delete the cluster and reprovision it.
source ./aks.vars
./15-aad-aks-sp.sh

# AKS AAD Integration
# As this required couple of AAD "Admin Consents". This might be executed with AAD tenant admin
source ./aks.vars
./16-aad-aks-auth.sh

# AKS Provisioning
# Please review the file before executing as based on the previously executed steps, you might need to make adjustments
./17-aks.sh