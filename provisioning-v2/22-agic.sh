#!/bin/bash

# If you have a private cluster, make sure you are connecting via jump-box or have VPN connectivity to the vnet

# Make sure that variables are updated
source ./$VAR_FILE

#***** App Gateway Ingress Controller Provisioning *****

# Docs: https://github.com/Azure/application-gateway-kubernetes-ingress 
# You can provision the AGIC either through using AAD Pod Identity or SP. As best practice, I'm using Pod Identity.

# Provision the app gateway (check script 10-app-gateway.sh)
# Note to maintain SLA, you need to set --min-capacity to at least 2 instances
# Azure Application Gateway must be v2 SKUs
# App Gateway will be used as ingress controller: https://azure.github.io/application-gateway-kubernetes-ingress/
# In earlier step we provisioned a vNet with a subnet dedicated for App Gateway and the application gateway v2.

# We need the resource id in order to assign role to AGW managed identity
AGW_RESOURCE_ID=$(az network application-gateway show --name $AGW_NAME --resource-group $RG_INFOSEC --query id --output tsv)
echo $AGW_RESOURCE_ID

# Installing App Gateway Ingress Controller
# Setup Documentation on existing cluster: https://azure.github.io/application-gateway-kubernetes-ingress/setup/install-existing/
# Setup Documentation on new cluster: https://azure.github.io/application-gateway-kubernetes-ingress/setup/install-new/

# AGIC needs to authenticate to ARM to be able to managed the App Gatway and ready AKS resources
# You have 2 options to do that

# Setting a name for AGW managed identity
AGW_IDENTITY_NAME="${PREFIX}-agw-msi-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"

### OPTION 1: Using (Pod Identity) - Recommended
# Assuming you got your Pod Identity setup completed successfully in the previous steps, let's provision the AGIC

# Creating User Managed Identity to be used to by AGIC to access AGW (integration is done through Pod Identity)
# Create new AD identity
AGW_MANAGED_IDENTITY=$(az identity create -g $RG_INFOSEC -n $AGW_IDENTITY_NAME)
# You can load the MSI of an existing one as well if you lost session or you have already one
# AGW_MANAGED_IDENTITY=$(az identity show -g $RG_INFOSEC -n $AGW_IDENTITY_NAME)
echo $AGW_MANAGED_IDENTITY | jq
#AGW_MANAGED_IDENTITY_CLIENTID=$(echo $AGW_MANAGED_IDENTITY | jq .clientId | tr -d '"')
AGW_MANAGED_IDENTITY_CLIENTID=$(echo $AGW_MANAGED_IDENTITY | jq -r .clientId)
echo $AGW_MANAGED_IDENTITY_CLIENTID
AGW_MANAGED_IDENTITY_ID=$(echo $AGW_MANAGED_IDENTITY | jq .id | tr -d '"')
echo $AGW_MANAGED_IDENTITY_ID
# We need the principalId for role assignment
AGW_MANAGED_IDENTITY_SP_ID=$(echo $AGW_MANAGED_IDENTITY | jq .principalId | tr -d '"')
echo $AGW_MANAGED_IDENTITY_SP_ID

# User Identity needs Reader access to AKS Resource Group and Nodes Resource Group, let's get its id
RG_ID=$(az group show --name $RG_AKS --query id -o tsv)
RG_NODE_NAME=$(az aks show \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --query nodeResourceGroup -o tsv)
RG_NODE_ID=$(az group show --name $RG_NODE_NAME --query id -o tsv)

echo $RG_ID
echo $RG_NODE_ID

# Create the assignment (note that you might need to wait if you got "no matches in graph database")
az role assignment create --role Reader --assignee $AGW_MANAGED_IDENTITY_CLIENTID --scope $RG_NODE_ID
az role assignment create --role Reader --assignee $AGW_MANAGED_IDENTITY_CLIENTID --scope $RG_ID
az role assignment create --role Contributor --assignee $AGW_MANAGED_IDENTITY_CLIENTID --scope $AGW_RESOURCE_ID
az role assignment create --role "Managed Identity Operator" --assignee $AKS_SP_ID --scope $AGW_MANAGED_IDENTITY_ID

# Note: Sometime you need to take a short break now before proceeding for the above assignments is for sure done.

# Installing using Helm 3
# Make sure you have Helm 3 installed
helm version
# If you need to install, run the following:
# curl -sL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo bash

# Adding AGIC helm repo
helm search repo -l application-gateway-kubernetes-ingress
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

# To get the latest helm-config.yaml for AGIC run this (notice you active folder)
# wget https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/sample-helm-config.yaml -O ./deployments/agic-helm-config.yaml

# have a look at the deployment:
# cat ./deployments/agic-helm-config.yaml

# Lets replace some values and output a new updated config

# Indicate that App GW is shared with other cluster or services. I will default to flase. This can be updated later
# docs: https://github.com/Azure/application-gateway-kubernetes-ingress/blob/072626cb4e37f7b7a1b0c4578c38d1eadc3e8701/docs/setup/install-existing.md#multi-cluster--shared-app-gateway
SHARED_AGW_FLAG=false

# In case, requirement is to restrict all Ingresses to be exposed over Private IP, use true in this flag
PRIVATE_IP_AGW_FLAG=false

# Required:
sed ./deployments/agic-helm-config.yaml \
    -e 's@<subscriptionId>@'"${SUBSCRIPTION_ID}"'@g' \
    -e 's@<resourceGroupName>@'"${RG_INFOSEC}"'@g' \
    -e 's@<applicationGatewayName>@'"${AGW_NAME}"'@g' \
    -e 's@<identityResourceId>@'"${AGW_MANAGED_IDENTITY_ID}"'@g' \
    -e 's@<identityClientId>@'"${AGW_MANAGED_IDENTITY_CLIENTID}"'@g' \
    -e "s/\(^.*usePrivateIP: \).*/\1${PRIVATE_IP_AGW_FLAG}/gI" \
    -e "s/\(^.*shared: \).*/\1${SHARED_AGW_FLAG}/gI" \
    -e "s/\(^.*enabled: \).*/\1true/gI" \
    > ./deployments/agic-helm-config-updated.yaml

# have a final look on the yaml before deploying :)
cat ./deployments/agic-helm-config-updated.yaml

# Note that this deployment doesn't specify a kubernetes namespace, which mean AGIC will monitor all namespaces

# Execute the installation (will not work with AKS v1.16+ as it introduced few breaking changes)
helm install ingress-azure \
    -f ./deployments/agic-helm-config-updated.yaml application-gateway-kubernetes-ingress/ingress-azure \
    --namespace default

# To have it run on 1.16+ as a workaround, you can use the following:
# git clone https://github.com/Azure/application-gateway-kubernetes-ingress.git
# helm install \
#     -f ./deployments/agic-helm-config-updated.yaml ingress-azure \
#     ./application-gateway-kubernetes-ingress/helm/ingress-azure

# Just check of the AGIC pods are up and running :)
kubectl get pods

### OPTION 2: Using (Service Principal) // Commented out for automated execution of this script

# Create a new SP to be used by AGIC through Kubernetes secrets
# AGIC_SP_NAME="${PREFIX}-agic-sp"
# AGIC_SP_AUTH=$(az ad sp create-for-rbac --skip-assignment --name $AGIC_SP_NAME --sdk-auth | base64 -w0)
# AGIC_SP=$(az ad sp show --id http://$AGIC_SP_NAME)
# echo $AGIC_SP | jq
# AGIC_SP_ID=$(echo $AGIC_SP | jq -r .appId)
# echo $AGIC_SP_ID

# az role assignment create --role Reader --assignee $AGIC_SP_ID --scope $RG_NODE_ID
# az role assignment create --role Reader --assignee $AGIC_SP_ID --scope $RG_ID
# az role assignment create --role Contributor --assignee $AGIC_SP_ID --scope $AGW_RESOURCE_ID

# sed ./deployments/agic-sp-helm-config.yaml \
#     -e 's@<subscriptionId>@'"${SUBSCRIPTION_ID}"'@g' \
#     -e 's@<resourceGroupName>@'"${RG}"'@g' \
#     -e 's@<applicationGatewayName>@'"${AGW_NAME}"'@g' \
#     -e 's@<secretJSON>@'"${AGIC_SP_AUTH}"'@g' \
#     -e "s/\(^.*enabled: \).*/\1true/gI" \
#     -e 's@<aks-api-server-address>@'"${AKS_FQDN}"'@g' \
#     > ./deployments/agic-sp-helm-config-updated.yaml

# have a final look on the yaml before deploying :)
# cat ./deployments/agic-sp-helm-config-updated.yaml

# Note that this deployment doesn't specify a kubernetes namespace, which mean AGIC will monitor all namespaces

# Execute the installation
# helm install --name $AGW_NAME \
#     -f ./deployments/agic-sp-helm-config-updated.yaml application-gateway-kubernetes-ingress/ingress-azure\
#     --namespace default

# Just check of the pods are up and running :)
# kubectl get pods

### Removing AGIC
# Helm make it easy to delete the AGIC deployment to start over
# helm del --purge $AGW_NAME

#***** END App Gateway Provisioning *****

echo "AGIC Scripts Execution Completed"