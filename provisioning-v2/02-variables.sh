#!/bin/bash

#Set some variables
# Any vars with REPLACE value you need to update via direct assignment or execute the instructed CLI commands

# - Project Variables
# - Azure Subscription Information
# - Resource groups
# - Azure Monitor
# - Networking
# - Key Vault
# - API Management
# - AAD Integration
# - ACR
# - Application Gateway
# - Azure Firewall
# - AKS Cluster
# - Public IPs

### Project Variables
# Have a project code (short like 2 or 3 letters)
# I selected "cap" for crowd-analytics-platform project I worked on

PROJECT_CODE="cap"
# Set the environment that this deployment represent (dev, qa, prod,...)
ENVIRONMENT="dev"
SUBSCRIPTION_CODE="ent"

# Primary location
LOCATION="westeurope"
# Location code will be used to setup multi-region resources
LOCATION_CODE="weu"

# Variable file will be used to store the values based on your deployment
VAR_FILE=$PROJECT_CODE-$ENVIRONMENT-$LOCATION_CODE-$SUBSCRIPTION_CODE.vars
if [ -f "$VAR_FILE" ]; then
    echo "Remove last version of the file $VAR_FILE"
    rm "$VAR_FILE"
fi

echo export VAR_FILE=$VAR_FILE >> ./$VAR_FILE
echo export PROJECT_CODE=$PROJECT_CODE >> ./$VAR_FILE
echo export ENVIRONMENT=$ENVIRONMENT >> ./$VAR_FILE
echo export SUBSCRIPTION_CODE=$SUBSCRIPTION_CODE >> ./$VAR_FILE

# Prefix is a combination of project and environment
PREFIX="${ENVIRONMENT}${PROJECT_CODE}"
echo export PREFIX=$PREFIX >> ./$VAR_FILE

echo export LOCATION=$LOCATION >> ./$VAR_FILE
echo export LOCATION_CODE=$LOCATION_CODE >> ./$VAR_FILE

# Azure subscription vars (uncomment if you will supply the values)
# SUBSCRIPTION_ID="REPLACE"
# TENANT_ID="REPLACE"
# echo export SUBSCRIPTION_ID=$SUBSCRIPTION_ID >> ./$VAR_FILE
# echo export TENANT_ID=$TENANT_ID >> ./$VAR_FILE

### Resource groups
echo export RG_AKS="${PREFIX}-aks-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE
echo export RG_AKS_NODES="${PREFIX}-aks-nodes-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE
echo export RG_INFOSEC="central-infosec-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE
echo export RG_SHARED="${PREFIX}-shared-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE
echo export RG_DEVOPS="${PREFIX}-devops-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE

### Azure Monitor
echo export SHARED_WORKSPACE_NAME="${PREFIX}-${SUBSCRIPTION_CODE}-shared-logs" >> ./$VAR_FILE
echo export HUB_EXT_WORKSPACE_NAME="${PREFIX}-${SUBSCRIPTION_CODE}-hub-logs" >> ./$VAR_FILE

# Creating Application Insights for each app
echo export APP_NAME="${PREFIX}-REPLACE-insights-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE

### Virtual networks
echo export PROJ_VNET_NAME="spoke-${PREFIX}-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE
echo export HUB_EXT_VNET_NAME="hub-ext-vnet-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE
# HUB_INT_VNET_NAME can be added to introduce on-premise connectivity


# AKS primary subnet
echo export AKS_SUBNET_NAME="${PREFIX}-aks" >> ./$VAR_FILE

# AKS exposed ingress services subnet
echo export SVC_SUBNET_NAME="${PREFIX}-ingress" >> ./$VAR_FILE

# Virutal nodes subnet (for serverless burst scaling)
echo export VN_SUBNET_NAME="${PREFIX}-vn" >> ./$VAR_FILE

# Development API Management subnet
echo export APIM_HOSTED_SUBNET_NAME="${PREFIX}-apim-dev" >> ./$VAR_FILE

# Project devops/jump-box subnet
echo export PROJ_DEVOPS_AGENTS_SUBNET_NAME="${PREFIX}-devops" >> ./$VAR_FILE

# Private enpoints subnet for connected Azure PaaS services and other resources
echo export PRIVATE_ENDPOINTS_SUBNET_NAME="${PREFIX}-pe" >> ./$VAR_FILE

# Production/hub API Management subnet
echo export APIM_SUBNET_NAME="hub-apim-prod" >> ./$VAR_FILE

# Production/hub self hosted agents
echo export DEVOPS_AGENTS_SUBNET_NAME="hub-devops" >> ./$VAR_FILE

# Application gateway subnet
echo export AGW_SUBNET_NAME="hub-waf" >> ./$VAR_FILE

# Hub DNS subnet
echo export DNS_SUBNET_NAME="hub-dns" >> ./$VAR_FILE

# Azure Firewall Subnet name must be AzureFirewallSubnet
echo export FW_SUBNET_NAME="AzureFirewallSubnet" >> ./$VAR_FILE

# IP ranges for each subnet (for simplicity some are created with /24)
# Always carefully plan your network size based on expected workloads
# Sizing docs: https://docs.microsoft.com/en-us/azure/aks/configure-azure-cni

# 2046 allocated addresses (from 8.0 to 15.255)
echo export PROJ_VNET_ADDRESS_SPACE_1="10.165.8.0/21" >> ./$VAR_FILE
# 2046 allocated addresses (from 16.0 to 23.255)
echo export PROJ_VNET_ADDRESS_SPACE_2="10.165.16.0/21" >> ./$VAR_FILE
# Incase you need the next address space, you can use this
# echo export PROJ_VNET_ADDRESS_SPACE_3="10.165.24.0/22" >> ./$VAR_FILE

# This /21 size would support around 60 node cluster (given that 30 pods/cluster is used)
echo export AKS_SUBNET_IP_PREFIX="10.165.8.0/21" >> ./$VAR_FILE
echo export VN_SUBNET_IP_PREFIX="10.165.16.0/22" >> ./$VAR_FILE
echo export SVC_SUBNET_IP_PREFIX="10.165.20.0/24" >> ./$VAR_FILE
echo export APIM_HOSTED_SUBNET_IP_PREFIX="10.165.21.0/24" >> ./$VAR_FILE
echo export PROJ_DEVOPS_AGENTS_SUBNET_IP_PREFIX="10.165.22.0/24" >> ./$VAR_FILE
echo export PRIVATE_ENDPOINTS_SUBNET_IP_PREFIX="10.165.23.0/24" >> ./$VAR_FILE

# 2048 allocated addresses (from 0.0 to 7.255)
echo export HUB_EXT_VNET_ADDRESS_SPACE="10.165.0.0/21" >> ./$VAR_FILE

echo export FW_SUBNET_IP_PREFIX="10.165.1.0/24" >> ./$VAR_FILE
echo export AGW_SUBNET_IP_PREFIX="10.165.2.0/24" >> ./$VAR_FILE
echo export APIM_SUBNET_IP_PREFIX="10.165.3.0/24" >> ./$VAR_FILE
echo export DEVOPS_AGENTS_SUBNET_IP_PREFIX="10.165.4.0/24" >> ./$VAR_FILE

echo export DNS_SUBNET_IP_PREFIX="10.165.5.0/24" >> ./$VAR_FILE
echo export DNS_VM_NIC_IP="10.165.5.5" >> ./$VAR_FILE

### Key Vault
echo export KEY_VAULT_PRIMARY="${PREFIX}-shared-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE

### API Management (Dev instance)
echo export APIM_NAME=$PREFIX-dev-apim-$SUBSCRIPTION_CODE-$LOCATION_CODE  >> ./$VAR_FILE
echo export APIM_ORGANIZATION_NAME="Mohamed-Saif" >> ./$VAR_FILE
echo export APIM_ADMIN_EMAIL="mohamed.saif@outlook.com" >> ./$VAR_FILE
echo export APIM_SKU="Developer" >> ./$VAR_FILE #Replace with "Premium" if you are deploying to production

### AAD Integration

# AKS Service Principal
echo export AKS_SP_NAME="${PREFIX}-aks-sp-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE
# The following will be loaded by AAD module
# AKS_SP_ID="REPLACE"
# AKS_SP_PASSWORD="REPLACE"
# echo export AKS_SP_NAME=$AKS_SP_NAME >> ./$VAR_FILE
# echo export AKS_SP_ID=$AKS_SP_ID >> ./$VAR_FILE
# echo export AKS_SP_PASSWORD=$AKS_SP_PASSWORD >> ./$VAR_FILE

# AAD Enabled Cluster
SERVER_APP_ID=REPLACE
echo export SERVER_APP_ID=$SERVER_APP_ID >> ./$VAR_FILE
SERVER_APP_SECRET=REPLACE
echo export SERVER_APP_SECRET=$SERVER_APP_SECRET >> ./$VAR_FILE
CLIENT_APP_ID=REPLACE
echo export CLIENT_APP_ID=$CLIENT_APP_ID >> ./$VAR_FILE

# AKS Pod Identity (for DEMO purposes)
PODS_MANAGED_IDENTITY_NAME="${PREFIX}-pod-identity-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"
PODS_MANAGED_IDENTITY_CLIENTID=REPLACE
PODS_MANAGED_IDENTITY_ID=REPLACE
PODS_MANAGED_IDENTITY_SP_ID=REPLACE
# Saving the MSI for later use
echo export PODS_MANAGED_IDENTITY_NAME=$PODS_MANAGED_IDENTITY_NAME >> ./$VAR_FILE
echo export PODS_MANAGED_IDENTITY_CLIENTID=$PODS_MANAGED_IDENTITY_CLIENTID >> ./$VAR_FILE
echo export PODS_MANAGED_IDENTITY_ID=$PODS_MANAGED_IDENTITY_ID >> ./$VAR_FILE
echo export PODS_MANAGED_IDENTITY_SP_ID=$PODS_MANAGED_IDENTITY_SP_ID >> ./$VAR_FILE

# AGIC Managed Identity
AGIC_MANAGED_IDENTITY_NAME="${PREFIX}-agic-identity-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"
echo export AGIC_MANAGED_IDENTITY_NAME=$AGIC_MANAGED_IDENTITY_NAME >> ./$VAR_FILE
# or use Service Principal
AGIC_SP_NAME="${PREFIX}-agic-sp-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"
# AGIC_SP_ID=REPLACE
# AGIC_SP_Password=REPLACE
echo export AGIC_SP_NAME=$AGIC_SP_NAME >> ./$VAR_FILE
echo export AGIC_SP_ID=$AGIC_SP_ID >> ./$VAR_FILE
echo export AGIC_SP_Password=$AGIC_SP_Password >> ./$VAR_FILE

### Azure Container Registry (ACR)
echo export CONTAINER_REGISTRY_NAME="acr${PREFIX}${SUBSCRIPTION_CODE}${LOCATION_CODE}" >> ./$VAR_FILE

### Application Gateway (AGW)
echo export AGW_NAME="${PREFIX}-agw-${SUBSCRIPTION_CODE}-${LOCATION_CODE}" >> ./$VAR_FILE
echo export AGW_PRIVATE_IP="10.165.2.10" >> ./$VAR_FILE
# echo export AGW_RESOURCE_ID=REPLACE >> ./$VAR_FILE

### Azure Firewall
FW_NAME="hub-ext-fw-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"
FW_IPCONFIG_NAME=$FW_NAME-ip-config
FW_UDR=$FW_NAME-udr
FW_UDR_ROUTE_NAME=$FW_IPCONFIG_NAME-route
echo export FW_NAME=$FW_NAME >> ./$VAR_FILE
echo export FW_IPCONFIG_NAME=$FW_IPCONFIG_NAME >> ./$VAR_FILE
echo export FW_UDR=$FW_UDR >> ./$VAR_FILE
echo export FW_UDR_ROUTE_NAME=$FW_UDR_ROUTE_NAME >> ./$VAR_FILE

### AKS Cluster
AKS_CLUSTER_NAME="${PREFIX}-aks-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"

# AKS version will be set at the cluster provisioning time
# AKS_VERSION=REPLACE

# Default node pool name must all small letters and not exceed 15 letters
AKS_DEFAULT_NODEPOOL="primary"

echo export AKS_CLUSTER_NAME=$AKS_CLUSTER_NAME >> ./$VAR_FILE
echo export AKS_VERSION=$AKS_VERSION >> ./$VAR_FILE
echo export AKS_DEFAULT_NODEPOOL=$AKS_DEFAULT_NODEPOOL >> ./$VAR_FILE

# AKS Networking
# Make sure that all of these ranges are not overlapping to any connected network space (on Azure and otherwise)
# These addresses are lated to AKS services mainly and should not overlap with other networks as they might present a conflict
echo export AKS_SERVICE_CIDR="10.41.0.0/16" >> ./$VAR_FILE
echo export AKS_DNS_SERVICE_IP="10.41.0.10" >> ./$VAR_FILE
echo export AKS_DOCKER_BRIDGE_ADDRESS="172.17.0.1/16" >> ./$VAR_FILE
# Range to be used when using kubenet (not Azure CNI)
echo export AKS_POD_CIDR="10.244.0.0/16" >> ./$VAR_FILE

# If you are using Windows Containers support, you need the following
WIN_USER="localwinadmin"
WIN_PASSWORD="P@ssw0rd1234"
WIN_NODEPOOL="${PREFIX}-win-np"
echo export WIN_USER=$WIN_USER >> ./$VAR_FILE
echo export WIN_PASSWORD=$WIN_PASSWORD >> ./$VAR_FILE
echo export WIN_NODEPOOL=$WIN_NOODEPOOL >> ./$VAR_FILE

### Public IPs
echo export AKS_PIP_NAME="${AKS_CLUSTER_NAME}-pip" >> ./$VAR_FILE
echo export AGW_PIP_NAME="${AGW_NAME}-pip" >> ./$VAR_FILE
echo export FW_PIP_NAME="${FW_NAME}-pip" >> ./$VAR_FILE

### Tags
# Saving the key/value pairs into variables
echo export TAG_ENV_DEV="Environment=DEV" >> ./$VAR_FILE
echo export TAG_ENV_STG="Environment=STG" >> ./$VAR_FILE
echo export TAG_ENV_QA="Environment=QA" >> ./$VAR_FILE
echo export TAG_ENV_PROD="Environment=PROD" >> ./$VAR_FILE
echo export TAG_ENV_DR_PROD="Environment=DR-PROD" >> ./$VAR_FILE
echo export TAG_PROJ_CODE="Project=${PROJECT_CODE}" >> ./$VAR_FILE
echo export TAG_PROJ_SHARED="Project=Shared-Service" >> ./$VAR_FILE
echo export TAG_DEPT_IT="Department=IT" >> ./$VAR_FILE
echo export TAG_STATUS_EXP="Status=Experimental" >> ./$VAR_FILE
echo export TAG_STATUS_PILOT="Status=PILOT" >> ./$VAR_FILE
echo export TAG_STATUS_APPROVED="Status=APPROVED" >> ./$VAR_FILE

# Reload the .bashrc variables
source ./$VAR_FILE

echo "Variables Scripts Execution Completed"

echo ""
echo "Please do source $VAR_FILE now before you execute any of the other scripts"
