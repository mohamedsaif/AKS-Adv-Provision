#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Create Azure Container Registry
az acr create \
    -g $RG_SHARED \
    -n $CONTAINER_REGISTRY_NAME \
    --sku Basic \
    --workspace $SHARED_WORKSPACE_NAME
    --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

# (PREVIEW) Private Link Support



az network vnet subnet update \
 --name $subnetName \
 --vnet-name $networkName \
 --resource-group $resourceGroup \
 --disable-private-endpoint-network-policies


echo "Container Registry Scripts Execution Completed"