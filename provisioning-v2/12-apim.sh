#!/bin/bash

# API Management
# In the architecture, I have 2 API management instances, one for development and one for production.
# API Management support migrating configurations deployed to dev to prod. So you can test the functionality of the service before rolling it out to production.

# The below script only provision the development instance of API Management in the vnet of the AKS cluster.

# Production APIM, should have Premium SKU to leverage the vnet integration. You need also to use the Hub vnet to deploy the prod APIM

# Make sure that variables are updated
source ./$VAR_FILE

# Subnet for Dev APIM
APIM_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $APIM_HOSTED_SUBNET_NAME --query id -o tsv)

# Subnet for Prod (if you want to deploy a prod)
# APIM_SUBNET_ID=$(az network vnet subnet show -g $RG_INFOSEC --vnet-name $HUB_EXT_VNET_NAME --name $APIM_SUBNET_NAME --query id -o tsv)

sed deployments/apim-deployment.json \
    -e s/APIM-NAME/$APIM_NAME/g \
    -e s/DEPLOYMENT-LOCATION/$LOCATION/g \
    -e s/DEPLOYMENT-ORGANIZATION/$APIM_ORGANIZATION_NAME/g \
    -e s/DEPLOYMENT-EMAIL/$APIM_ADMIN_EMAIL/g \
    -e 's@DEPLOYMENT-SUBNET-ID@'"${APIM_SUBNET_ID}"'@g' \
    -e s/DEPLOYMENT-SKU/$APIM_SKU/g \
    -e s/ENVIRONMENT-VALUE/DEV/g \
    -e s/PROJECT-VALUE/Shared-Service/g \
    -e s/DEPARTMENT-VALUE/IT/g \
    -e s/STATUS-VALUE/Experimental/g \
    > apim-deployment-updated.json

# Deployment can take a few mins
APIM=$(az group deployment create \
    --resource-group $RG_SHARED \
    --name $PREFIX-apim-deployment \
    --template-file apim-deployment-updated.json)

# echo export APIM=$APIM >> ./$VAR_FILE

az monitor diagnostic-settings create \
    --resource $APIM_NAME \
    --resource-group $RG_SHARED\
    --name $APIM_NAME-logs \
    --resource-type "Microsoft.ApiManagement/service" \
    --workspace $SHARED_WORKSPACE_NAME \
    --logs '[
        {
            "category": "GatewayLogs",
            "enabled": true,
            "retentionPolicy": {
                "enabled": false,
                "days": 30
            }
        }
    ]' \
    --metrics '[
        {
            "category": "AllMetrics",
            "enabled": true,
            "retentionPolicy": {
                "enabled": false,
                "days": 30
            }
        }
    ]'

echo "APIM Scripts Execution Completed"