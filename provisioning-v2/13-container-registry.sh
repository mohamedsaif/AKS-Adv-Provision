#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Create Azure Container Registry
az acr create \
    -g $RG_SHARED \
    -n $CONTAINER_REGISTRY_NAME \
    --sku Standard \
    --workspace $SHARED_WORKSPACE_NAME \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

CONTAINER_REGISTRY_ID=$(az acr show --name $CONTAINER_REGISTRY_NAME \
  --query 'id' --output tsv)

echo export CONTAINER_REGISTRY_ID=$CONTAINER_REGISTRY_ID >> ./$VAR_FILE

# Adding Private Link Support

# az network vnet subnet update \
#  --name $ \
#  --vnet-name $PROJ_VNET_NAME \
#  --resource-group $resourceGroup \
#  --disable-private-endpoint-network-policies

# az network private-dns zone create \
#   --resource-group $RG_SHARED \
#   --name "privatelink.azurecr.io"

# az network private-dns link vnet create \
#   --resource-group $RG_SHARED \
#   --zone-name "privatelink.azurecr.io" \
#   --name acr-private-link-$PROJ_VNET_NAME-dns \
#   --virtual-network $PROJ_VNET_NAME \
#   --registration-enabled false

# az network private-endpoint create \
#     --name $CONTAINER_REGISTRY_NAME \
#     --resource-group $RG_SHARED \
#     --vnet-name $PROJ_VNET_NAME \
#     --subnet $SUBNET_NAME \
#     --private-connection-resource-id $REGISTRY_ID \
#     --group-ids registry \
#     --connection-name myConnection

echo "Container Registry Scripts Execution Completed"
