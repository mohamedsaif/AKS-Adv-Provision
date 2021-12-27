#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

HUB_BASTION_NAME=hub-bastion-$SUBSCRIPTION_CODE-$LOCATION_CODE
HUB_BASTION_PUBLIC_IP_NAME=hub-bastion-$SUBSCRIPTION_CODE-$LOCATION_CODE-pip

az network public-ip create \
  --resource-group $RG_INFOSEC \
  --name $HUB_BASTION_PUBLIC_IP_NAME \
  --sku Standard \
  --location $LOCATION

az network bastion create \
  --name $HUB_BASTION_NAME \
  --public-ip-address $HUB_BASTION_PUBLIC_IP_NAME \
  --resource-group $RG_INFOSEC \
  --vnet-name $HUB_EXT_VNET_NAME \
  --location $LOCATION

echo "Azure Bastion Scripts Execution Completed"