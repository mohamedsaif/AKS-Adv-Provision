#!/bin/bash

#***** Prepare Service Principal for AKS *****

# AKS Service Principal
# Docs: https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/aks/kubernetes-service-principal.md
# AKS provision Azure resources based on the cluster needs, 
# like automatic provision of storage or creating public load balancer
# Also AKS needs to communicate with AzureRM APIs through that SP
# You can use the automatically generated SP if you omitted the SP configuration in AKS creation process

# Create a SP to be used by AKS
AKS_SP=$(az ad sp create-for-rbac -n $AKS_SP_NAME --skip-assignment)

# As the json result stored in AKS_SP, we use some jq Kung Fu to extract the values 
# jq documentation: (https://shapeshed.com/jq-json/#how-to-pretty-print-json)
echo $AKS_SP | jq
AKS_SP_ID=$(echo $AKS_SP | jq -r .appId)
AKS_SP_PASSWORD=$(echo $AKS_SP | jq -r .password)
echo $AKS_SP_ID
echo $AKS_SP_PASSWORD

# OR you can retrieve back existing SP any time:
# AKS_SP=$(az ad sp show --id http://$AKS_SP_NAME)
# AKS_SP_ID=$(echo $AKS_SP | jq -r .appId)
# AKS_SP_PASSWORD="REPLACE_SP_PASSWORD"

# Don't have the password, get new password for SP (careful not to void in-use SP account)
# AKS_SP=$(az ad sp credential reset --name $AKS_SP_ID)
# AKS_SP_ID=$(echo $AKS_SP | jq -r .appId)
# AKS_SP_PASSWORD=$(echo $AKS_SP | jq -r .password)
# echo $AKS_SP_ID
# echo $AKS_SP_PASSWORD

# Save the new variables
echo export AKS_SP_NAME=$AKS_SP_NAME >> ~/.bashrc
echo export AKS_SP_ID=$AKS_SP_ID >> ~/.bashrc
echo export AKS_SP_PASSWORD=$AKS_SP_PASSWORD >> ~/.bashrc

# Get also the AAD object id for the SP for later use
AKS_SP_OBJ_ID=$(az ad sp show --id ${AKS_SP_ID} --query objectId -o tsv)
echo $AKS_SP_OBJ_ID
echo export AKS_SP_OBJ_ID=$AKS_SP_OBJ_ID >> ~/.bashrc

# As we used --skip-assignment, we will be assigning the SP to various services later
# These assignment like ACR, vNET and other resources that will require AKS to access
# az role assignment create --assignee $AKS_SP_ID --scope <resourceScope> --role Contributor

# To update existing AKS cluster SP, use the following command (when needed):
# az aks update-credentials \
#     --resource-group $RG \
#     --name $CLUSTER_NAME \
#     --reset-service-principal \
#     --service-principal $AKS_SP_ID \
#     --client-secret $AKS_SP_PASSWORD

#***** END Prepare Service Principal for AKS *****

#***** Prepare AAD for AKS *****

### AKS AAD Prerequisites
# Further documentation can be found here https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli

# If AAD Enabled Cluster is needed, you need to configure that before cluster creation
# A lot of organization restrict access to the AAD tenant, 
# you can ask the Azure AD Tenant Administrator to perform the below actions
# Remember that AAD authentication is for USERS not systems :)
# Also you can't enable AAD on an existing AKS cluster
# I used my own subscription and AAD Tenant, so I was the tenant admin :)

# Create the Azure AD application to act as identity endpoint for the identity requests
SERVER_APP_ID=$(az ad app create \
    --display-name "${CLUSTER_NAME}-server" \
    --identifier-uris "https://${CLUSTER_NAME}-server" \
    --query appId -o tsv)
echo $SERVER_APP_ID
echo export SERVER_APP_ID=$SERVER_APP_ID >> ~/.bashrc
# Update the application group membership claims
az ad app update --id $SERVER_APP_ID --set groupMembershipClaims=All

# Create a service principal for the Azure AD app to use it to authenticate itself
az ad sp create --id $SERVER_APP_ID

# Get the service principal secret through reset :) This will work also with existing SP
SERVER_APP_SECRET=$(az ad sp credential reset \
    --name $SERVER_APP_ID \
    --credential-description "AKSPassword" \
    --query password -o tsv)
echo $SERVER_APP_SECRET
echo export SERVER_APP_SECRET=$SERVER_APP_SECRET >> ~/.bashrc
# Assigning permissions for readying directory, sign in and read user profile data to SP
az ad app permission add \
    --id $SERVER_APP_ID \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role

# Now granting them. Expect "Forbidden" error if you are not Azure tenant admin :(
az ad app permission grant --id $SERVER_APP_ID --api 00000003-0000-0000-c000-000000000000
# As we need Read All data, we require the admin consent (this require AAD tenant admin)
# Azure tenant admin can login to AAD and grant this from the portal
az ad app permission admin-consent --id  $SERVER_APP_ID

### Client AAD Setup (like when a user connects using kubectl)

# Create new AAD app
CLIENT_APP_ID=$(az ad app create \
    --display-name "${CLUSTER_NAME}-client" \
    --native-app \
    --reply-urls "https://${CLUSTER_NAME}-client" \
    --query appId -o tsv)
echo $CLIENT_APP_ID
echo export CLIENT_APP_ID=$CLIENT_APP_ID >> ~/.bashrc

# Creation SP for the client
az ad sp create --id $CLIENT_APP_ID

# We need the OAuth token from the server app created in the previous step. This will allow authentication flow between the two app components
OAUTH_PREMISSION_ID=$(az ad app show --id $SERVER_APP_ID --query "oauth2Permissions[0].id" -o tsv)

# Adding and granting OAuth flow between the server and client apps
az ad app permission add --id $CLIENT_APP_ID --api $SERVER_APP_ID --api-permissions $OAUTH_PREMISSION_ID=Scope

# Again with the "Forbidden" error if you are not Azure tenant admin
az ad app permission grant --id $CLIENT_APP_ID --api $SERVER_APP_ID

#***** END Prepare AAD for AKS *****