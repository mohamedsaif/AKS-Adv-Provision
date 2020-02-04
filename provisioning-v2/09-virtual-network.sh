#!/bin/bash

# Make sure that variables are updated
source ~/.bashrc

# Double check the ranges you setup in the variables file

echo export AKS_SUBNET_IP_PREFIX="10.165.10.0/21" >> ~/.bashrc
echo export VN_SUBNET_IP_PREFIX="10.165.16.0/22" >> ~/.bashrc
echo export SVCS_UBNET_IP_PREFIX="10.165.20.0/24" >> ~/.bashrc
echo export APIM_HOSTED_SUBNET_IP_PREFIX="10.165.21.0/24" >> ~/.bashrc

echo export FW_SUBNET_IP_PREFIX="10.165.4.0/24" >> ~/.bashrc
echo export AGW_SUBNET_IP_PREFIX="10.165.5.0/24" >> ~/.bashrc
echo export APIM_SUBNET_IP_PREFIX="10.165.6.0/24" >> ~/.bashrc
echo export DEVOPS_AGENTS_SUBNET_IP_PREFIX="10.165.7.0/24" >> ~/.bashrc


echo export PROJ_VNET_NAME="${PREFIX}-vnet-${LOCATION_CODE}" >> ~/.bashrc

echo export HUB_EXT_VNET_NAME="hub-ext-vnet-${LOCATION_CODE}" >> ~/.bashrc
echo export PROJ_VNET_ADDRESS_SPACE="10.165.10.0/23 10.165.12.0/22 10.165.16.0/21" >> ~/.bashrc
echo export HUB_EXT_VNET_ADDRESS_SPACE="10.165.4.0/22 10.165.8.0/23" >> ~/.bashrc
# HUB_INT_VNET_NAME can be added to introduce on-premise connectivity

# AKS primary subnet
echo export AKS_SUBNET_NAME="${PREFIX}-aks" >> ~/.bashrc

# AKS exposed services subnet
echo export SVC_SUBNET_NAME="${PREFIX}-svc" >> ~/.bashrc

# Application gateway subnet
echo export AGW_SUBNET_NAME="${PREFIX}-agw" >> ~/.bashrc

# Azure Firewall Subnet name must be AzureFirewallSubnet
echo export FW_SUBNET_NAME="AzureFirewallSubnet" >> ~/.bashrc

# Virutal nodes subnet (for serverless burst scaling)
echo export VN_SUBNET_NAME="${PREFIX}-vn" >> ~/.bashrc

# Azure API Management Subnet
echo export APIM_SUBNET_NAME="${PREFIX}-apim" >> ~/.bashrc

# Self hosted agents
echo export DEVOPS_AGENTS_SUBNET_NAME="${PREFIX}-apim" >> ~/.bashrc


# First we create the project virtual network
az network vnet create \
    --resource-group $RG_AKS \
    --name $PROJ_VNET_NAME \
    --address-prefixes $PROJ_VNET_ADDRESS_SPACE \
    --subnet-name $AKS_SUBNET_NAME \
    --subnet-prefix $AKS_SUBNET_IP_PREFIX

# Create subnet for Virtual Nodes
az network vnet subnet create \
    --resource-group $RG_AKS \
    --vnet-name $PROJ_VNET_NAME \
    --name $VN_SUBNET_NAME \
    --address-prefix $VN_SUBNET_IP_PREFIX

# Create subnet for kubernetes exposed services (usually by internal load-balancer)
# Good security practice to isolate exposed services from the internal services
az network vnet subnet create \
    --resource-group $RG_AKS \
    --vnet-name $PROJ_VNET_NAME \
    --name $SVC_SUBNET_IP_NAME \
    --address-prefix $SVC_SUBNET_IP_PREFIX

# Create subnet for APIM self hosted gateway
az network vnet subnet create \
    --resource-group $RG_AKS \
    --vnet-name $PROJ_VNET_NAME \
    --name $APIM_HOSTED_SUBNET_NAME \
    --address-prefix $APIM_HOSTED_SUBNET_IP_PREFIX

# Second we create the virtual network for the external hub
az network vnet create \
    --resource-group $RG_AKS \
    --name $HUB_EXT_VNET_NAME \
    --address-prefixes $HUB_EXT_VNET_ADDRESS_SPACE \
    --subnet-name $AKS_SUBNET_NAME \
    --subnet-prefix $AKS_SUBNET_IP_PREFIX

# Create subnet for App Gateway
az network vnet subnet create \
    --resource-group $RG_AKS \
    --vnet-name $HUB_EXT_VNET_NAME \
    --name $AGW_SUBNET_NAME \
    --address-prefix $AGW_SUBNET_IP_PREFIX

# Create subnet for Azure Firewall
az network vnet subnet create \
    --resource-group $RG_AKS \
    --vnet-name $HUB_EXT_VNET_NAME \
    --name $FW_SUBNET_NAME \
    --address-prefix $FW_SUBNET_IP_PREFIX

# Create subnet for APIM
az network vnet subnet create \
    --resource-group $RG_AKS \
    --vnet-name $HUB_EXT_VNET_NAME \
    --name $APIM_SUBNET_NAME \
    --address-prefix $APIM_SUBNET_IP_PREFIX

# Create subnet for DevOps agents
az network vnet subnet create \
    --resource-group $RG_AKS \
    --vnet-name $HUB_EXT_VNET_NAME \
    --name $DEVOPS_AGENTS_SUBNET_NAME \
    --address-prefix $DEVOPS_AGENTS_SUBNET_IP_PREFIX