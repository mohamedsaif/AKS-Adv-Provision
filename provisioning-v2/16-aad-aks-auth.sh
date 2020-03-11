#!/bin/bash

# Make sure that variables are updated
source ./aks.vars

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
echo export SERVER_APP_ID=$SERVER_APP_ID >> ./aks.vars
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
echo export SERVER_APP_SECRET=$SERVER_APP_SECRET >> ./aks.vars
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

# Note about Azure Monitor for container
# If you wish for an AAD-enabled cluster users to leverage Azure Monitor from Azure Portal, 
# you need to add the following reply-urls (space separated) to your client
# https://afd.hosting.portal.azure.net/monitoring/Content/iframe/infrainsights.app/web/base-libs/auth/auth.html
# https://monitoring.hosting.portal.azure.net/monitoring/Content/iframe/infrainsights.app/web/base-libs/auth/auth.html

# Create new AAD app
CLIENT_APP_ID=$(az ad app create \
    --display-name "${CLUSTER_NAME}-client" \
    --native-app \
    --reply-urls "https://${CLUSTER_NAME}-client" \
    --query appId -o tsv)
echo $CLIENT_APP_ID
echo export CLIENT_APP_ID=$CLIENT_APP_ID >> ./aks.vars

# Creation SP for the client
az ad sp create --id $CLIENT_APP_ID

# We need the OAuth token from the server app created in the previous step. This will allow authentication flow between the two app components
OAUTH_PREMISSION_ID=$(az ad app show --id $SERVER_APP_ID --query "oauth2Permissions[0].id" -o tsv)

# Adding and granting OAuth flow between the server and client apps
az ad app permission add --id $CLIENT_APP_ID --api $SERVER_APP_ID --api-permissions $OAUTH_PREMISSION_ID=Scope

# Again with the "Forbidden" error if you are not Azure tenant admin
az ad app permission grant --id $CLIENT_APP_ID --api $SERVER_APP_ID

#***** END Prepare AAD for AKS *****

echo "AKS Scripts Execution Completed"