#!/bin/bash

# Primary script to orchestrate end-to-end execution

# General note: I would highly recommend executing scripts manually (opening them 1 by 1) for the first time to get familiar with the provisioned services

# Switch to provisioning-v2 folder
cd provisioning-v2

# Marking the script files to be executable
chmod -R +x .


# Variables
# Double check the variables script before execution (you might need to replace some values)
./02-variables.sh
# Reload to make sure everything is updated in the current session
# First time you use this, $VAR_FILE will not yet have the correct value, please set it up explicitly here based on the value from the variables file
VAR_FILE=cap-dev-gbb.vars
source ./$VAR_FILE
# You can save this variables file so it can be used later
# Check the variables (it might be long :)
# export

# Login
# If you are signed in, it will get the subscription and tenant ids. If not, you need to follow instructions in the script to login.
source ./$VAR_FILE
./03-login.sh

# Preview Providers
# Please review before execution
source ./$VAR_FILE
./04-preview-providers.sh

# Tags setup
# Please review before execution
# You need to run it once per subscription. Also you need to run the project tag for every project code you use this script with
./05-tags.sh

# Resource Groups
source ./$VAR_FILE
./06-resource-groups.sh

# Monitoring (be patient.. it might take couple of mins)
source ./$VAR_FILE
./07-monitoring.sh

# Azure Key Vault
source ./$VAR_FILE
./08-key-vault.sh

# Virtual Network
source ./$VAR_FILE
./09-virtual-network.sh

# Application Gateway
source ./$VAR_FILE
./10-app-gateway.sh

# Jump-box and DevOps agent
# You might receive prompts around generating the RSA keys
# If you want to SSH to this jump-box, check the script for instructions.
source ./$VAR_FILE
./11-jump-box.sh

# API Management Service (APIM)
# be patient.. it might take several of mins
source ./$VAR_FILE
./12-apim.sh

# Container Registry (ACR)
source ./$VAR_FILE
./13-container-registry.sh

# AKS outbound PIP
source ./$VAR_FILE
./14-aks-pip.sh

# AKS Service Principal
# Please review the script before executing
# Service principal can be reused if you needed to delete or create new cluster.
source ./$VAR_FILE
./15-aad-aks-sp.sh

# AKS AAD Integration
# Please review the script before executing
# As this required couple of AAD "Admin Consents". This might be executed with AAD tenant admin
source ./$VAR_FILE
./16-aad-aks-auth.sh

# AKS Provisioning
# Please review the file before executing as based on the previously executed steps, you might need to make adjustments
# You have 2 options now to provision AKS cluster.
# Public AKS Masters
./17-aks-public.sh
# OR
# Private AKS Masters
./17-aks-private.sh

# Pod Identity
# Please review the file before executing as based on the previously executed steps, you might need to make adjustments
# If you have a private cluster, make sure you are using jump-box or have VPN connectivity setup
./21-pod-identity.sh
# If you want to test pod-identity deployment, check the script ./22-pod-identity-demo.sh

# Application Gateway Ingress Controller (AGIC)
# Please review the file before executing as based on the previously executed steps, you might need to make adjustments
# If you have a private cluster, make sure you are using jump-box or have VPN connectivity setup
./22-agic.sh
# If you want to test agic deployment, check the script ./22-agic-demo.sh


