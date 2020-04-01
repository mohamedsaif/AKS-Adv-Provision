#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Create public IP for the gateway. 
# Using standard sku allow extra security as it is closed by default and allow traffic through NSGs
# More info here: https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-ip-addresses-overview-arm
az network public-ip create \
    -g $RG_AKS \
    -n $AKS_PIP_NAME \
    -l $LOCATION \
    --sku Standard \
    --tags $TAG_ENV_DEV $TAG_PROJ_CODE $TAG_DEPT_IT $TAG_STATUS_EXP

echo "AKS Public IP Scripts Execution Completed"