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
    --zone 1 2 3 \
    --dns-name $AKS_PIP_NAME \
    --tags $TAG_ENV $TAG_PROJ_CODE $TAG_DEPT_IT $TAG_STATUS_EXP

AKS_PIP_ID=$(az network public-ip show --name $AKS_PIP_NAME -g $RG_AKS \
  --query 'id' --output tsv)
echo $AKS_PIP_ID
echo export AKS_PIP_ID=$AKS_PIP_ID >> ./$VAR_FILE

echo "AKS Public IP Scripts Execution Completed"
