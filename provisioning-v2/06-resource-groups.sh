#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# My approach will use 3 primary resource groups (1 additional will be created by AKS for the nodes)
# - Project resource group: main resource group used to provision directly connected services to AKS deployment (like storage)
# - Infrastructure resource group: will host all services that can be shared across multiple clusters (like Container Registry and Azure Traffic Manager)
# - InfoSec resource group: to host networking security resources (like Key Vault, App Gateway and Azure Firewall which can be reused across multiple clusters)

az group create \
    --name $RG_AKS \
    --location $LOCATION \
    --tags $TAG_ENV_DEV $TAG_PROJ_CODE $TAG_DEPT_IT $TAG_STATUS_EXP

az group create \
    --name $RG_INFOSEC \
    --location $LOCATION  \
    --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

az group create \
    --name $RG_SHARED \
    --location $LOCATION \
    --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

echo "Resource Groups Creation Completed"