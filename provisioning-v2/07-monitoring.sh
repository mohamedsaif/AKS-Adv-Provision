#!/bin/bash

# Make sure that variables are updated
source ./aks.vars

# AKS Log Analytics Workspace
# Update the deployment template with selected location
sed deployments/logs-workspace-deployment.json \
    -e s/WORKSPACE-NAME/$SHARED_WORKSPACE_NAME/g \
    -e s/DEPLOYMENT-LOCATION/$LOCATION/g \
    -e s/ENVIRONMENT-VALUE/DEV/g \
    -e s/PROJECT-VALUE/Shared-Service/g \
    -e s/DEPARTMENT-VALUE/IT/g \
    -e s/STATUS-VALUE/Experimental/g \
    > shared-logs-workspace-deployment-updated.json

# Deployment can take a few mins
SHARED_WORKSPACE=$(az group deployment create \
    --resource-group $RG_SHARED \
    --name $PREFIX-shared-logs-workspace-deployment \
    --template-file shared-logs-workspace-deployment-updated.json)

SHARED_WORKSPACE_ID=$(echo $SHARED_WORKSPACE | jq -r '.properties["outputResources"][].id')

echo export SHARED_WORKSPACE_ID=$SHARED_WORKSPACE_ID >> ./aks.vars

# AKS Log Analytics Workspace
# Update the deployment template with selected location
sed deployments/logs-workspace-deployment.json \
    -e s/WORKSPACE-NAME/$HUB_EXT_WORKSPACE_NAME/g \
    -e s/DEPLOYMENT-LOCATION/$LOCATION/g \
    -e s/ENVIRONMENT-VALUE/DEV/g \
    -e s/PROJECT-VALUE/Shared-Service/g \
    -e s/DEPARTMENT-VALUE/IT/g \
    -e s/STATUS-VALUE/Experimental/g \
    > hub-logs-workspace-deployment-updated.json

# Deployment can take a few mins
HUB_WORKSPACE=$(az group deployment create \
    --resource-group $RG_INFOSEC \
    --name $PREFIX-hub-logs-workspace-deployment \
    --template-file hub-logs-workspace-deployment-updated.json)

HUB_WORKSPACE_ID=$(echo $HUB_WORKSPACE | jq -r '.properties["outputResources"][].id')
echo export HUB_WORKSPACE_ID=$HUB_WORKSPACE_ID >> ./aks.vars

# In addition to Azure Monitor for containers, you can deploy app insights to your application code
# App Insights support many platforms like .NET, Java, and NodeJS.
# Docs: https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview
# Check Kubernetes apps with no instrumentation and service mesh: https://docs.microsoft.com/en-us/azure/azure-monitor/app/kubernetes
# Create App Insights to be used within your apps:
APP_NAME="${PREFIX}-crowd-analytics-${LOCATION_CODE}"
APP_INSIGHTS_KEY=$(az resource create \
    --resource-group ${RG_SHARED} \
    --resource-type "Microsoft.Insights/components" \
    --name ${APP_NAME} \
    --location ${LOCATION} \
    --properties '{"Application_Type":"web"}' \
    | grep -Po "\"InstrumentationKey\": \K\".*\"")

az resource tag \
    --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP \
    -g $RG_SHARED \
    -n $APP_NAME \
    --resource-type "Microsoft.Insights/components"
echo export APP_INSIGHTS_KEY=$APP_INSIGHTS_KEY >> ./aks.vars

echo "Variables Scripts Execution Completed"