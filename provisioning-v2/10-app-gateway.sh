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
    --resource-group $RG_INFOSEC

# Creating App Gateway Identity
az identity create \
    --resource-group $RG_INFOSEC \
    --name $AGW_IDENTITY_NAME

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
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP \
    --query id -o tsv

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


echo export AGW_RESOURCE_ID=$AGW_RESOURCE_ID >> ./$VAR_FILE
echo export AGW_IDENTITY_CLIENTID=$AGW_IDENTITY_CLIENTID >> ./$VAR_FILE
echo export AGW_IDENTITY_OID=$AGW_IDENTITY_OID >> ./$VAR_FILE

echo "AGW Scripts Execution Completed"
