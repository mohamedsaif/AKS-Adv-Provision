#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Note: double check the ranges you setup in the variables file
# Note: AKS clusters may not use 169.254.0.0/16, 172.30.0.0/16, 172.31.0.0/16, or 192.0.2.0/24

# First we create the project virtual network
az network vnet create \
    --resource-group $RG_SHARED \
    --name $PROJ_VNET_NAME \
    --address-prefixes $PROJ_VNET_ADDRESS_SPACE_1 $PROJ_VNET_ADDRESS_SPACE_2 \
    --subnet-name $AKS_SUBNET_NAME \
    --subnet-prefix $AKS_SUBNET_IP_PREFIX \
    --tags $TAG_ENV_DEV $TAG_PROJ_CODE $TAG_DEPT_IT $TAG_STATUS_EXP

# Create subnet for Virtual Nodes
az network vnet subnet create \
    --resource-group $RG_SHARED \
    --vnet-name $PROJ_VNET_NAME \
    --name $VN_SUBNET_NAME \
    --address-prefix $VN_SUBNET_IP_PREFIX

# Create subnet for kubernetes exposed services (usually by internal load-balancer)
# Good security practice to isolate exposed services from the internal services
az network vnet subnet create \
    --resource-group $RG_SHARED \
    --vnet-name $PROJ_VNET_NAME \
    --name $SVC_SUBNET_NAME \
    --address-prefix $SVC_SUBNET_IP_PREFIX

# Create subnet for APIM self-hosted gateway (dev APIM)
az network vnet subnet create \
    --resource-group $RG_SHARED \
    --vnet-name $PROJ_VNET_NAME \
    --name $APIM_HOSTED_SUBNET_NAME \
    --address-prefix $APIM_HOSTED_SUBNET_IP_PREFIX

# Create subnet for APIM self-hosted gateway
az network vnet subnet create \
    --resource-group $RG_SHARED \
    --vnet-name $PROJ_VNET_NAME \
    --name $PROJ_DEVOPS_AGENTS_SUBNET_NAME \
    --address-prefix $PROJ_DEVOPS_AGENTS_SUBNET_IP_PREFIX

# Second we create the virtual network for the external hub (with Firewall subnet)
az network vnet create \
    --resource-group $RG_INFOSEC \
    --name $HUB_EXT_VNET_NAME \
    --address-prefixes $HUB_EXT_VNET_ADDRESS_SPACE \
    --subnet-name $FW_SUBNET_NAME \
    --subnet-prefix $FW_SUBNET_IP_PREFIX \
    --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

# Create subnet for App Gateway
az network vnet subnet create \
    --resource-group $RG_INFOSEC \
    --vnet-name $HUB_EXT_VNET_NAME \
    --name $AGW_SUBNET_NAME \
    --address-prefix $AGW_SUBNET_IP_PREFIX

# Create subnet for APIM
az network vnet subnet create \
    --resource-group $RG_INFOSEC \
    --vnet-name $HUB_EXT_VNET_NAME \
    --name $APIM_SUBNET_NAME \
    --address-prefix $APIM_SUBNET_IP_PREFIX

# Create subnet for DevOps agents
az network vnet subnet create \
    --resource-group $RG_INFOSEC \
    --vnet-name $HUB_EXT_VNET_NAME \
    --name $DEVOPS_AGENTS_SUBNET_NAME \
    --address-prefix $DEVOPS_AGENTS_SUBNET_IP_PREFIX

# Get the id for project vnet.
PROJ_VNET_ID=$(az network vnet show \
    --resource-group $RG_SHARED \
    --name $PROJ_VNET_NAME \
    --query id --out tsv)

HUB_VNET_ID=$(az network vnet show \
    --resource-group $RG_INFOSEC \
    --name $HUB_EXT_VNET_NAME \
    --query id --out tsv)

# Peer Hub to Project-Spoke network
az network vnet peering create \
    --name $HUB_EXT_VNET_NAME-peer-$PROJ_VNET_NAME \
    --resource-group $RG_INFOSEC \
    --vnet-name $HUB_EXT_VNET_NAME \
    --remote-vnet-id "${PROJ_VNET_ID}" \
    --allow-vnet-access

# Peer Project-Spoke network to Hub
az network vnet peering create \
    --name $PROJ_VNET_NAME-peer-$HUB_EXT_VNET_NAME \
    --resource-group $RG_SHARED \
    --vnet-name $PROJ_VNET_NAME \
    --remote-vnet-id "${HUB_VNET_ID}" \
    --allow-vnet-access