#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Create Azure Container Registry
az acr create \
    -g $RG_SHARED \
    -n $CONTAINER_REGISTRY_NAME \
    --sku Premium \
    --workspace $SHARED_WORKSPACE_NAME \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

CONTAINER_REGISTRY_ID=$(az acr show --name $CONTAINER_REGISTRY_NAME \
  --query 'id' --output tsv)

echo export CONTAINER_REGISTRY_ID=$CONTAINER_REGISTRY_ID >> ./$VAR_FILE

# Adding Private Link Support
PE_SUBNET_ID=$(az network vnet subnet update \
 --name $PRIVATE_ENDPOINTS_SUBNET_NAME \
 --vnet-name $PROJ_VNET_NAME \
 --resource-group $RG_SHARED \
 --query 'id' --output tsv)
echo export PE_SUBNET_ID=$PE_SUBNET_ID >> ./$VAR_FILE

az network vnet subnet update \
 --name $PRIVATE_ENDPOINTS_SUBNET_NAME \
 --vnet-name $PROJ_VNET_NAME \
 --resource-group $RG_SHARED \
 --disable-private-endpoint-network-policies

az network private-dns zone create \
  --resource-group $RG_INFOSEC \
  --name "privatelink.azurecr.io"

az network private-dns link vnet create \
  --resource-group $RG_INFOSEC \
  --zone-name "privatelink.azurecr.io" \
  --name acr-private-link-$HUB_EXT_VNET_NAME-dns \
  --virtual-network $HUB_VNET_ID \
  --registration-enabled false

az network private-endpoint create \
    --name $CONTAINER_REGISTRY_NAME-pe \
    --resource-group $RG_SHARED \
    --subnet $PE_SUBNET_ID \
    --private-connection-resource-id $CONTAINER_REGISTRY_ID \
    --group-id registry \
    --connection-name $CONTAINER_REGISTRY_NAME-to-$PROJ_VNET_NAME

NETWORK_INTERFACE_ID=$(az network private-endpoint show \
  --name $CONTAINER_REGISTRY_NAME-pe \
  --resource-group $RG_SHARED \
  --query 'networkInterfaces[0].id' \
  --output tsv)
echo $NETWORK_INTERFACE_ID

REGISTRY_PRIVATE_IP=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateIpAddress" \
  --output tsv)
echo $REGISTRY_PRIVATE_IP

DATA_ENDPOINT_PRIVATE_IP=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_$LOCATION'].privateIpAddress" \
  --output tsv)
echo $DATA_ENDPOINT_PRIVATE_IP

# An FQDN is associated with each IP address in the IP configurations

REGISTRY_FQDN=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateLinkConnectionProperties.fqdns" \
  --output tsv)
echo $REGISTRY_FQDN

DATA_ENDPOINT_FQDN=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_$LOCATION'].privateLinkConnectionProperties.fqdns" \
  --output tsv)
echo $DATA_ENDPOINT_FQDN

# Create DNS records
az network private-dns record-set a create \
  --name $CONTAINER_REGISTRY_NAME \
  --zone-name privatelink.azurecr.io \
  --resource-group $RG_INFOSEC

# Specify registry region in data endpoint name
az network private-dns record-set a create \
  --name ${CONTAINER_REGISTRY_NAME}.${LOCATION}.data \
  --zone-name privatelink.azurecr.io \
  --resource-group $RG_INFOSEC

# Assigning the private IPs
az network private-dns record-set a add-record \
  --record-set-name $CONTAINER_REGISTRY_NAME \
  --zone-name privatelink.azurecr.io \
  --resource-group $RG_INFOSEC \
  --ipv4-address $REGISTRY_PRIVATE_IP

# Specify registry region in data endpoint name
az network private-dns record-set a add-record \
  --record-set-name ${CONTAINER_REGISTRY_NAME}.${LOCATION}.data \
  --zone-name privatelink.azurecr.io \
  --resource-group $RG_INFOSEC \
  --ipv4-address $DATA_ENDPOINT_PRIVATE_IP

echo "Container Registry Scripts Execution Completed"
