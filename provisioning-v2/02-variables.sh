#Set some variables
# Any vars with REPLACE value you need to update via direct assignment or execute the instructed CLI commands

# - Project Variables
# - Azure Subscription Information
# - Resource groups
# - Azure Monitor
# - Networking
# - AAD Integration
# - ACR
# - Application Gateway
# - Azure Firewall
# - AKS Cluster

### Project Variables
# Have a project code (short like 2 or 3 letters)
# I selected "cap" for crowd-analytics-platform project I worked on
PROJECT_CODE="cap"
# Set the environment that this deployment represent (dev, qa, prod,...)
ENVIRONMENT="dev"

# Prefix is a combination of project and environment
PREFIX="${ENVIRONMENT}${PROJECT_CODE}"
echo export PREFIX=$PREFIX >> ~/.bashrc

# Primary location
LOCATION="westeurope"
# Location code will be used to setup multi-region resources
LOCATION_CODE="weu"
echo export LOCATION=$LOCATION >> ~/.bashrc
echo export LOCATION_CODE=$LOCATION_CODE >> ~/.bashrc

# Azure subscription vars
SUBSCRIPTION_ID="REPLACE"
TENANT_ID="REPLACE"
echo export SUBSCRIPTION_ID=$SUBSCRIPTION_ID >> ~/.bashrc
echo export TENANT_ID=$TENANT_ID >> ~/.bashrc

### Resource groups
AKS_RG="${PREFIX}-rg-${LOCATION_CODE}"
AKS_RG_NODES="${RG}-nodes-${LOCATION_CODE}";
RG_INFOSEC="${PREFIX}-rg-infosec-${LOCATION_CODE}"
RG_SRE="${PREFIX}-rg-sre-${LOCATION_CODE}"

echo export AKS_RG=$AKS_RG >> ~/.bashrc
echo export AKS_RG_NODES=$AKS_RG_NODES >> ~/.bashrc
echo export RG_INFOSEC=$RG_INFOSEC >> ~/.bashrc
echo export RG_SRE=$RG_SRE >> ~/.bashrc

### Azure Monitor
WORKSPACE_NAME="${PREFIX}-logs"
echo export WORKSPACE_NAME=$WORKSPACE_NAME >> ~/.bashrc

# Creating Application Insights for each app
APP_NAME="${PREFIX}-REPLACE-insights-${LOCATION_CODE}"
APPINSIGHTS_KEY=REPLACE

### Virtual networks
VNET_NAME="${PREFIX}-vnet-${LOCATION_CODE}"

# AKS primary subnet
AKS_SUBNET_NAME="${PREFIX}-akssubnet"

# AKS exposed services subnet
SVC_SUBNET_NAME="${PREFIX}-svcsubnet"

# Application gateway subnet
AGW_SUBNET_NAME="${PREFIX}-appgwsubnet"

# Azure Firewall Subnet name must be AzureFirewallSubnet
FW_SUBNET_NAME="AzureFirewallSubnet"

# Virutal nodes subnet (for serverless burst scaling)
VN_SUBNET_NAME="${PREFIX}-vnsubnet"

# IP ranges for each subnet (for simplicity some are created with /24)
# Always carefully plan your network size based on expected workloads
# Sizing docs: https://docs.microsoft.com/en-us/azure/aks/configure-azure-cni
AKS_SUBNET_IP_PREFIX="10.42.1.0/24"
SVCS_UBNET_IP_PREFIX="10.42.2.0/24"
AGW_SUBNET_IP_PREFIX="10.42.3.0/24"
FW_SUBNET_IP_PREFIX="10.42.4.0/24"
VN_SUBNET_IP_PREFIX="10.42.5.0/24"

# Public IPs
AKS_PIP_NAME="${AKS_CLUSTER_NAME}-pip"
AGW_PIP_NAME="${AGW_NAME}-pip"
FW_PIP_NAME="${FW_NAME}-pip"

echo export VNET_NAME=$VNET_NAME >> ~/.bashrc
echo export AKS_SUBNET_NAME=$AKS_SUBNET_NAME >> ~/.bashrc
echo export SVC_SUBNET_NAME=$SVC_SUBNET_NAME >> ~/.bashrc
echo export AGW_SUBNET_NAME=$AGW_SUBNET_NAME >> ~/.bashrc
echo export FW_SUBNET_NAME=$FW_SUBNET_NAME >> ~/.bashrc
echo export VN_SUBNET_NAME=$VN_SUBNET_NAME >> ~/.bashrc
echo export AKS_SUBNET_IP_PREFIX=$AKS_SUBNET_IP_PREFIX >> ~/.bashrc
echo export SVCS_UBNET_IP_PREFIX=$SVCS_UBNET_IP_PREFIX >> ~/.bashrc
echo export AGW_SUBNET_IP_PREFIX=$AGW_SUBNET_IP_PREFIX >> ~/.bashrc
echo export FW_SUBNET_IP_PREFIX=$FW_SUBNET_IP_PREFIX >> ~/.bashrc
echo export VN_SUBNET_IP_PREFIX=$VN_SUBNET_IP_PREFIX >> ~/.bashrc
echo export AKS_PIP_NAME=$AKS_PIP_NAME >> ~/.bashrc
echo export AGW_PIP_NAME=$AGW_PIP_NAME >> ~/.bashrc
echo export FW_PIP_NAME=$FW_PIP_NAME >> ~/.bashrc

### AAD Integration

# AKS Service Principal
AKS_SP_NAME="${PREFIX}-aks-sp-${LOCATION_CODE}"
AKS_SP_ID="REPLACE"
AKS_SP_PASSWORD="REPLACE"
echo export AKS_SP_NAME=$AKS_SP_NAME >> ~/.bashrc
echo export AKS_SP_ID=$AKS_SP_ID >> ~/.bashrc
# echo export AKS_SP_PASSWORD=$AKS_SP_PASSWORD >> ~/.bashrc

# AAD Enabled Cluster
SERVER_APP_ID=REPLACE
echo export SERVER_APP_ID=$SERVER_APP_ID >> ~/.bashrc
SERVER_APP_SECRET=REPLACE
echo export SERVER_APP_SECRET=$SERVER_APP_SECRET >> ~/.bashrc
CLIENT_APP_ID=REPLACE
echo export CLIENT_APP_ID=$CLIENT_APP_ID >> ~/.bashrc

# AKS Pod Identity
PODS_MANAGED_IDENTITY_NAME="${PREFIX}-pods-default-identity-${LOCATION_CODE}"
PODS_MANAGED_IDENTITY_CLIENTID=REPLACE
PODS_MANAGED_IDENTITY_ID=REPLACE
PODS_MANAGED_IDENTITY_SP_ID=REPLACE
# Saving the MSI for later use
echo export PODS_MANAGED_IDENTITY_NAME=$PODS_MANAGED_IDENTITY_NAME >> ~/.bashrc
echo export PODS_MANAGED_IDENTITY_CLIENTID=$PODS_MANAGED_IDENTITY_CLIENTID >> ~/.bashrc
echo export PODS_MANAGED_IDENTITY_ID=$PODS_MANAGED_IDENTITY_ID >> ~/.bashrc
echo export PODS_MANAGED_IDENTITY_SP_ID=$PODS_MANAGED_IDENTITY_SP_ID >> ~/.bashrc

# AGIC Managed Identity
AGIC_MANAGED_IDENTITY_NAME="${PREFIX}-agic-identity-${LOCATION_CODE}"
# or use Service Principal
AGIC_SP_NAME="${PREFIX}-agic-sp-${LOCATION_CODE}"
AGIC_SP_ID=REPLACE

### ACR
CONTAINER_REGISTRY_NAME="${PREFIX}${LOCATION_CODE}acr"
echo export CONTAINER_REGISTRY_NAME=$CONTAINER_REGISTRY_NAME >> ~/.bashrc

### Application Gateway
AGW_NAME="${PREFIX}-agw-${LOCATION_CODE}"
AGW_RESOURCE_ID=REPLACE

### Azure Firewall
FW_NAME="${PREFIX}-fw-${LOCATION_CODE}"
FW_IPCONFIG_NAME="${FW_NAME}-ip-config"
FW_UDR=$FW_NAME-udr
FW_UDR_ROUTE_NAME=$FW_IPCONFIG_NAME-route

### AKS Cluster
AKS_CLUSTER_NAME="${PREFIX}-aks-${LOCATION_CODE}"
AKS_VERSION=REPLACE
AKS_DEFAULT_NODEPOOL="${PREFIX}-default-np"
AKS_RESOURCE_ID=REPLACE
AKS_FQDN=REPLACE
echo export AKS_CLUSTER_NAME=$AKS_CLUSTER_NAME >> ~/.bashrc

# If you are using Windows Containers support, you need the following
WIN_USER="localwinadmin"
WIN_PASSWORD="P@ssw0rd1234"
WIN_NODEPOOL="${PREFIX}-win-np"
echo export WIN_USER=$WIN_USER >> ~/.bashrc
echo export WIN_PASSWORD=$WIN_PASSWORD >> ~/.bashrc
echo export WIN_NODEPOOL=$WIN_NOODEPOOL >> ~/.bashrc

