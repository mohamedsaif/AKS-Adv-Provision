#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# We will be using these tags to mark all of the deployments with project/Environment pairs
# ONLY execute ONCE the creation and adding of values

# Some variables are referenced in the 02-variables.sh script

az tag create --name Environment
az tag create --name Project
az tag create --name Department
az tag create --name Status

az tag add-value \
    --name Environment \
    --value DEV

az tag add-value \
    --name Environment \
    --value STG

az tag add-value \
    --name Environment \
    --value QA

az tag add-value \
    --name Environment \
    --value PROD

az tag add-value \
    --name Environment \
    --value DR-PROD

az tag add-value \
    --name Project \
    --value $PROJECT_CODE

az tag add-value \
    --name Project \
    --value Shared-Service

az tag add-value \
    --name Department \
    --value IT

az tag add-value \
    --name Status \
    --value Experimental

az tag add-value \
    --name Status \
    --value PILOT

az tag add-value \
    --name Status \
    --value Approved

# Saving the key/value pairs into variables
# This is only a reference, the tags savings to variables happen in the 02-variables.sh if you need to update it
# echo export TAG_ENV_DEV="Environment=DEV" >> ./$VAR_FILE
# echo export TAG_ENV_STG="Environment=STG" >> ./$VAR_FILE
# echo export TAG_ENV_QA="Environment=QA" >> ./$VAR_FILE
# echo export TAG_ENV_PROD="Environment=PROD" >> ./$VAR_FILE
# echo export TAG_ENV_DR_PROD="Environment=DR-PROD" >> ./$VAR_FILE
# echo export TAG_PROJ_CODE="Project=${PROJECT_CODE}" >> ./$VAR_FILE
# echo export TAG_PROJ_SHARED="Project=Shared-Service" >> ./$VAR_FILE
# echo export TAG_DEPT_IT="Department=IT" >> ./$VAR_FILE
# echo export TAG_STATUS_EXP="Status=Experimental" >> ./$VAR_FILE
# echo export TAG_STATUS_PILOT="Status=PILOT" >> ./$VAR_FILE
# echo export TAG_STATUS_APPROVED="Status=APPROVED" >> ./$VAR_FILE

# This is created at the level of the subscription. So we will append --tags 'key1=value1 key2=value2'
# Tagging can help in setting up policies, cost management and other scenarios. 

source ./$VAR_FILE

echo "Tags Creation Completed"