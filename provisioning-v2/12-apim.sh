#!/bin/bash

# Make sure that variables are updated
source ~/.bashrc
echo export APIM_NAME=$PREFIX-shared-APIM  >> ~/.bashrc
echo export APIM_ORGANIZATION_NAME="MohamedSaif" >> ~/.bashrc
echo export APIM_ADMIN_EMAIL="mohamed.saif@outlook.com" >> ~/.bashrc
echo export APIM_SKU="Developer" >> ~/.bashrc #Replace with "Premium" if you are deploying to production

APIM_SUBNET_ID=$(az network vnet subnet show -g $RG_INFOSEC --vnet-name $HUB_EXT_VNET_NAME --name $APIM_SUBNET_NAME --query id -o tsv)

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
    --resource-group $RG_INFOSEC \
    --name $PREFIX-apim-deployment \
    --template-file apim-deployment-updated.json)

echo export APIM=$APIM >> ~/.bashrc

az monitor diagnostic-settings create \
    --resource $APIM_NAME \
    --resource-group $RG_INFOSEC\
    --name $APIM_NAME-logs \
    --resource-type "Microsoft.ApiManagement/service" \
    --workspace $HUB_EXT_WORKSPACE_NAME \
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