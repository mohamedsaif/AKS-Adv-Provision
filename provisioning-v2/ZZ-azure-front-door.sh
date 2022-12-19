#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

FRONT_DOOR_PROFILE_NAME=$PREFIX-afd-$SUBSCRIPTION_CODE-$LOCATION_CODE
ORIGIN_GROUP_WEB=primary-web
ORIGIN_GROUP_API=primary-api
ORIGIN_1=web-weu
ORIGIN_1_HOST=replace.domain.com
ORIGIN_2=web-neu
ORIGIN_2_HOST=replace2.domain.com

az afd profile create \
    --profile-name $FRONT_DOOR_PROFILE_NAME \
    --resource-group $RG_INFOSEC \
    --sku Premium_AzureFrontDoor

az afd endpoint create \
    --resource-group $RG_INFOSEC \
    --endpoint-name $FRONT_DOOR_PROFILE_NAME-api \
    --profile-name $FRONT_DOOR_PROFILE_NAME \
    --enabled-state Enabled

az afd endpoint create \
    --resource-group $RG_INFOSEC \
    --endpoint-name $FRONT_DOOR_PROFILE_NAME-web \
    --profile-name $FRONT_DOOR_PROFILE_NAME \
    --enabled-state Enabled

az afd origin-group create \
    --resource-group $RG_INFOSEC \
    --origin-group-name $ORIGIN_GROUP_API \
    --profile-name $FRONT_DOOR_PROFILE_NAME \
    --probe-request-type GET \
    --probe-protocol Https \
    --probe-interval-in-seconds 60 \
    --probe-path / \
    --sample-size 4 \
    --successful-samples-required 3 \
    --additional-latency-in-milliseconds 50

az afd origin-group create \
    --resource-group $RG_INFOSEC \
    --origin-group-name $ORIGIN_GROUP_WEB \
    --profile-name $FRONT_DOOR_PROFILE_NAME \
    --probe-request-type GET \
    --probe-protocol Https \
    --probe-interval-in-seconds 60 \
    --probe-path / \
    --sample-size 4 \
    --successful-samples-required 3 \
    --additional-latency-in-milliseconds 50

# First origin
az afd origin create \
    --resource-group $RG_INFOSEC \
    --host-name $ORIGIN_1_HOST \
    --profile-name $FRONT_DOOR_PROFILE_NAME \
    --origin-group-name $ORIGIN_GROUP \
    --origin-name $ORIGIN_1 \
    --origin-host-header $ORIGIN_1_HOST \
    --priority 1 \
    --weight 1000 \
    --enabled-state Enabled \
    --http-port 80 \
    --https-port 443

# second Origion
az afd origin create \
    --resource-group $RG_INFOSEC \
    --host-name $ORIGIN_2_HOST \
    --profile-name $FRONT_DOOR_PROFILE_NAME \
    --origin-group-name $ORIGIN_GROUP \
    --origin-name ORIGIN_2 \
    --origin-host-header $ORIGIN_2_HOST \
    --priority 1 \
    --weight 1000 \
    --enabled-state Enabled \
    --http-port 80 \
    --https-port 443

echo "Azure Front Door Scripts Execution Completed"