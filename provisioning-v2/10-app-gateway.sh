#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

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
    --zone 1 2 3 \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

# Creating WAF policy
az network application-gateway waf-policy create \
    --name $AGW_WAF_POLICY_NAME \
    --resource-group $RG_INFOSEC \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

# Creating App Gateway Identity
az identity create \
    --resource-group $RG_INFOSEC \
    --name $AGW_IDENTITY_NAME \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

# Provision the app gateway
# Note to maintain SLA, you need to set --min-capacity to at least 2 instances
# Azure Application Gateway must be v2 SKUs
# App Gateway can be used as native kubernetes ingress controller: https://azure.github.io/application-gateway-kubernetes-ingress/
# In earlier step we provisioned a vNet with a subnet dedicated for App Gateway.
    # --servers $SPRING_APP_PRIVATE_FQDN \
    # --key-vault-secret-id $KEYVAULT_SECRET_ID_FOR_CERT \
az network application-gateway create \
    --name $AGW_NAME \
    --resource-group $RG_INFOSEC \
    --location $LOCATION \
    --capacity 2 \
    --sku WAF_v2 \
    --frontend-port 80 \
    --http-settings-cookie-based-affinity Disabled \
    --http-settings-port 80 \
    --http-settings-protocol Http \
    --public-ip-address $AGW_PIP_NAME \
    --private-ip-address $AGW_PRIVATE_IP \
    --vnet-name $HUB_EXT_VNET_NAME \
    --subnet $AGW_SUBNET_NAME \
    --identity $AGW_IDENTITY_NAME \
    --priority 1001 \
    --waf-policy $AGW_WAF_POLICY_NAME \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

AGW_RESOURCE_ID=$(az network application-gateway show \
    --name $AGW_NAME \
    --resource-group $RG_INFOSEC \
    --query id -o tsv)


if [ "X$AGW_RESOURCE_ID" == "X" ]; then
    echo "Did not get an ID :-( try to find it now"
    export AGW_RESOURCE_ID=`az network application-gateway list -g "$RG_INFOSEC" | grep '"id"' | grep "/applicationGateways/[^\/]*," | sed s/\",// | sed s/^.*\"//`
fi

# If you have existing AGW, you can load instead
# AGW_RESOURCE_ID=$(az network application-gateway show --name $AGW_NAME --resource-group $RG_INFOSEC --query id --output tsv)

# Granting App Gateway Identity access to AKV
AGW_IDENTITY_CLIENTID=$(az identity show --resource-group $RG_INFOSEC --name $AGW_IDENTITY_NAME --query clientId --output tsv)
AGW_IDENTITY_OID=$(az ad sp show --id $AGW_IDENTITY_CLIENTID --query id --output tsv)
echo $AGW_IDENTITY_CLIENTID
echo $AGW_IDENTITY_OID

az keyvault set-policy \
    --name $KEY_VAULT_PRIMARY \
    --resource-group $RG_INFOSEC \
    --object-id $AGW_IDENTITY_OID \
    --secret-permissions get list \
    --certificate-permissions get list

echo export AGW_RESOURCE_ID=$AGW_RESOURCE_ID >> ./$VAR_FILE
echo export AGW_IDENTITY_CLIENTID=$AGW_IDENTITY_CLIENTID >> ./$VAR_FILE
echo export AGW_IDENTITY_OID=$AGW_IDENTITY_OID >> ./$VAR_FILE

# Adding Network Security Group
# Docs: https://learn.microsoft.com/EN-us/azure/application-gateway/configuration-infrastructure
AGW_SUBNET_NSG_NAME=hub-agw-nsg

az network nsg create \
   --name $AGW_SUBNET_NSG_NAME \
   --resource-group $RG_INFOSEC \
   --location $LOCATION

# Allowing traffic from Azure Gateway Manager 
az network nsg rule create \
    -g $RG_INFOSEC \
    --nsg-name $AGW_SUBNET_NSG_NAME \
    -n app-gateway-management-endpoints \
    --priority 100 \
    --source-address-prefixes GatewayManager  \
    --destination-port-ranges '65200-65535' \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --description "Application gateway management endpoints"

# Allowing traffic only from AFD
az network nsg rule create \
    -g $RG_INFOSEC \
    --nsg-name $AGW_SUBNET_NSG_NAME \
    -n adf-ingress \
    --priority 110 \
    --source-address-prefixes AzureFrontDoor.Backend  \
    --destination-port-ranges '443' \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --description "Azure Front Door Traffic"

# Associating the nsg with waf subnet
AGW_SUBNET_NSG_ID=$(az network nsg show -g $RG_INFOSEC -n $AGW_SUBNET_NSG_NAME --query "id" -o tsv)
az network vnet subnet update \
   -g $RG_INFOSEC \
   -n $AGW_SUBNET_NAME \
   --vnet-name $HUB_EXT_VNET_NAME \
   --network-security-group $AGW_SUBNET_NSG_ID

# Enabling private link

# Get Application Gateway Frontend IP Name
# az network application-gateway frontend-ip list \
# 							--gateway-name AppGW-PL-CLI \
# 							--resource-group AppGW-PL-CLI-RG

# # Add a new Private Link configuration and associate it with an existing Frontend IP
# az network application-gateway private-link add \
# 							--frontend-ip appGwPublicFrontendIp \
# 							--name privateLinkConfig01 \
# 							--subnet /subscriptions/XXXXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX/resourceGroups/AppGW-PL-CLI-RG/providers/Microsoft.Network/virtualNetworks/AppGW-PL-CLI-VNET/subnets/AppGW-PL-Subnet \
# 							--gateway-name AppGW-PL-CLI \
# 							--resource-group AppGW-PL-CLI-RG

# # Get Private Link resource ID
# az network application-gateway private-link list \
# 				--gateway-name AppGW-PL-CLI \
# 				--resource-group AppGW-PL-CLI-RG



# Disable Private Endpoint Network Policies
# https://learn.microsoft.com/azure/private-link/disable-private-endpoint-network-policy
# az network vnet subnet update \
# 				--name MySubnet \
# 				--vnet-name AppGW-PL-Endpoint-CLI-VNET \
# 				--resource-group AppGW-PL-Endpoint-CLI-RG \
# 				--disable-private-endpoint-network-policies true

# # Create Private Link Endpoint - Group ID is the same as the frontend IP configuration
# az network private-endpoint create \
# 	--name AppGWPrivateEndpoint \
# 	--resource-group AppGW-PL-Endpoint-CLI-RG \
# 	--vnet-name AppGW-PL-Endpoint-CLI-VNET \
# 	--subnet MySubnet \
# 	--group-id appGwPublicFrontendIp \
# 	--private-connection-resource-id /subscriptions/XXXXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX/resourceGroups/AppGW-PL-CLI-RG/providers/Microsoft.Network/applicationGateways/AppGW-PL-CLI \
# 	--connection-name AppGW-PL-Connection

# # If dns settings updated after the gateway started, you need to restart:
# az network application-gateway stop \
#   -g $RG_INFOSEC \
#   -n $AGW_NAME

# az network application-gateway start \
#   -g $RG_INFOSEC \
#   -n $AGW_NAME

echo "AGW Scripts Execution Completed"
