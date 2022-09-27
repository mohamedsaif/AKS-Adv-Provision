#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Creating Azure Key Vault
AKV_ID=$(az keyvault create \
    --name $KEY_VAULT_PRIMARY \
    --resource-group $RG_INFOSEC \
    --location $LOCATION \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP \
    --query id -o tsv)
echo $AKV_ID
# Getting existing key vault
# AKV=$(az keyvault show --name $KEYVAULT_PRIMARY)
# echo $AKV
# AKV_ID=$(echo $AKV | jq -r .id)

# If you are using existing Key Vault, you need to make sure that soft delete is enabled
# az resource update --id $(az keyvault show --name ${KEYVAULT_PRIMARY} -o tsv | awk '{print $1}') --set properties.enableSoftDelete=true

# setting up Key Vault private link
az network private-endpoint create \
    --resource-group $RG_INFOSEC \
    --vnet-name $HUB_EXT_VNET_NAME \
    --subnet $PRIVATE_ENDPOINTS_SUBNET_NAME \
    --name pe-shared-keyvault \
    --private-connection-resource-id $AKV_ID \
    --group-id vault \
    --connection-name shared-keyvault-connection \
    --location $LOCATION

az network private-dns zone create \
    --resource-group $RG_INFOSEC \
    --name "privatelink.vaultcore.azure.net"

az network private-dns link vnet create \
    --resource-group $RG_INFOSEC \
    --zone-name "privatelink.vaultcore.azure.net" \
    --name KeyVaultDNSLink \
    --virtual-network $HUB_EXT_VNET_NAME \
    --registration-enabled false

KEYVAULT_NIC_ID=$(az network private-endpoint show --name pe-shared-keyvault --resource-group $RG_INFOSEC --query 'networkInterfaces[0].id' -o tsv)
KEYVAULT_NIC_IPADDRESS=$(az resource show --ids $KEYVAULT_NIC_ID --api-version 2019-04-01 -o json | jq -r '.properties.ipConfigurations[0].properties.privateIPAddress')
echo $KEYVAULT_NIC_IPADDRESS

az network private-dns record-set a add-record -g $RG_INFOSEC -z "privatelink.vaultcore.azure.net" -n $KEY_VAULT_PRIMARY -a $KEYVAULT_NIC_IPADDRESS
# az network private-dns record-set list -g $RG_INFOSEC -z "privatelink.vaultcore.azure.net" -o table


echo export AKV_ID=$AKV_ID >> ./$VAR_FILE
echo export KEYVAULT_NIC_IPADDRESS=$KEYVAULT_NIC_IPADDRESS >> ./$VAR_FILE

source ./$VAR_FILE

echo "Key Vault Scripts Execution Completed"
