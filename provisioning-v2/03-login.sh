
# Only if needed: A browser window will open to complete the authentication :)
# az login

# You can also login using Service Principal (replace values in <>)
# az login --service-principal --username APP_ID --password PASSWORD --tenant TENANT_ID

# Make sure to set explicitly the subscription to avoid accessing incorrect one
# az account set --subscription "YOUR-SUBSCRIPTION-NAME"

#Make sure the active subscription is set correctly

echo "Setting up subscription and tenant id based on the signed in account"

SUBSCRIPTION_ACCOUNT=$(az account show)
echo $SUBSCRIPTION_ACCOUNT

# Get the tenant ID
TENANT_ID=$(echo $SUBSCRIPTION_ACCOUNT | jq -r .tenantId)
# or use TENANT_ID=$(az account show --query tenantId -o tsv)
echo $TENANT_ID
echo export TENANT_ID=$TENANT_ID >> ./$VAR_FILE

# Get the subscription ID
SUBSCRIPTION_ID=$(echo $SUBSCRIPTION_ACCOUNT | jq -r .id)
# or use TENANT_ID=$(az account show --query tenantId -o tsv)
echo $SUBSCRIPTION_ID
echo export SUBSCRIPTION_ID=$SUBSCRIPTION_ID >> ./$VAR_FILE

clear

echo "Subscription Id: ${SUBSCRIPTION_ID}"
echo "Tenant Id: ${TENANT_ID}"

echo "Login Script Completed"