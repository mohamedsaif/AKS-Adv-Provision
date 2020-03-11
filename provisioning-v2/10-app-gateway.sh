#!/bin/bash

# Make sure that variables are updated
source ./aks.vars

# This article assumes using Application Gateway v2. Many of the mentioned scripts will not work with v1
# Check your target region availability before proceeding

# I will be using the Application Gateway in dual mode, Public and Private endpoints

# Create public IP for the gateway. 
# Using standard sku allow extra security as it is closed by default and allow traffic through NSGs
# More info here: https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-ip-addresses-overview-arm
az network public-ip create \
    -g $RG_INFOSEC \
    -n $AGW_PIP_NAME \
    -l $LOCATION \
    --sku Standard \
    --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

# Provision the app gateway
# Note to maintain SLA, you need to set --min-capacity to at least 2 instances
# Azure Application Gateway must be v2 SKUs
# App Gateway can be used as native kubernetes ingress controller: https://azure.github.io/application-gateway-kubernetes-ingress/
# In earlier step we provisioned a vNet with a subnet dedicated for App Gateway.

AGW_RESOURCE_ID=$(az network application-gateway create \
  --name $AGW_NAME \
  --resource-group $RG_INFOSEC \
  --location $LOCATION \
  --min-capacity 2 \
  --frontend-port 80 \
  --http-settings-cookie-based-affinity Disabled \
  --http-settings-port 80 \
  --http-settings-protocol Http \
  --routing-rule-type Basic \
  --sku WAF_v2 \
  --private-ip-address $AGW_PRIVATE_IP \
  --public-ip-address $AGW_PIP_NAME \
  --subnet $AGW_SUBNET_NAME \
  --vnet-name $HUB_EXT_VNET_NAME \
  --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP \
  --query id -o tsv)

# If you have existing AGW, you can load instead
# AGW_RESOURCE_ID=$(az network application-gateway show --name $AGW_NAME --resource-group $RG_INFOSEC --query id --output tsv)

echo export AGW_RESOURCE_ID=$AGW_RESOURCE_ID >> ./aks.vars

echo "AGW Scripts Execution Completed"