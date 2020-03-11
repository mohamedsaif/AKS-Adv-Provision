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
# Check the variables (it might be long :)
export

# Login
./03-login.sh

# Preview Providers
# Please review before execution
./04-preview-providers.sh

# Tags setup
# Please review before execution
# You need to run it once per subscription
./05-tags.sh

# Resource Groups
./06-resource-groups.sh

# Monitoring (be patient.. it might take couple of mins)
./07-monitoring.sh

# Azure Key Vault
./08-key-vault.sh

# Virtual Network
./07-virtual-network.sh

