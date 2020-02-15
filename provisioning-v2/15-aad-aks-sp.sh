#!/bin/bash

#***** Prepare Service Principal for AKS *****

# AKS Service Principal
# Docs: https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/aks/kubernetes-service-principal.md
# AKS provision Azure resources based on the cluster needs, 
# like automatic provision of storage or creating public load balancer
# Also AKS needs to communicate with AzureRM APIs through that SP
# You can use the automatically generated SP if you omitted the SP configuration in AKS creation process

# Create a SP to be used by AKS 
# NOTE: (you should use this only once)
IS_NEW_SP=false
if [ "$AKS_SP" == null ] || [ -z "$AKS_SP" ]
then
    echo "New SP is needed"
    AKS_SP=$(az ad sp create-for-rbac -n $AKS_SP_NAME --skip-assignment)
    IS_NEW_SP=true
else
    echo "Existing SP is used"
fi

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

# To update existing AKS cluster SP, use the following command (when needed):
# az aks update-credentials \
#     --resource-group $RG \
#     --name $CLUSTER_NAME \
#     --reset-service-principal \
#     --service-principal $AKS_SP_ID \
#     --client-secret $AKS_SP_PASSWORD

### SP RBAC
# As we used --skip-assignment, we will be assigning the SP to various services later
# These assignment like ACR, vNET and other resources that will require AKS to access
# az role assignment create --assignee $AKS_SP_ID --scope <resourceScope> --role <role-name-or-id>

# AKS Resource Group
# I will give a contributor access on the resource group that holds directly provisioned resources used only by AKS
RG_AKS_ID=$(az group show --name $RG_AKS --query id -o tsv)
az role assignment create --assignee $AKS_SP_ID --scope $RG_AKS_ID --role "Contributor"

# vNet RBAC
AKS_SUBNET_ID=$(az network vnet subnet show -g $RG_AKS --vnet-name $PROJ_VNET_NAME --name $AKS_SUBNET_NAME --query id -o tsv)
AKS_SVC_SUBNET_ID=$(az network vnet subnet show -g $RG_AKS --vnet-name $PROJ_VNET_NAME --name $SVC_SUBNET_NAME --query id -o tsv)
AKS_VN_SUBNET_ID=$(az network vnet subnet show -g $RG_AKS --vnet-name $PROJ_VNET_NAME --name $VN_SUBNET_NAME --query id -o tsv)
APIM_HOSTED_SUBNET_ID=$(az network vnet subnet show -g $RG_AKS --vnet-name $PROJ_VNET_NAME --name $APIM_HOSTED_SUBNET_NAME --query id -o tsv)
az role assignment create --assignee $AKS_SP_ID --scope $AKS_SUBNET_ID --role "Network Contributor"
az role assignment create --assignee $AKS_SP_ID --scope $AKS_SVC_SUBNET_ID --role "Network Contributor"
az role assignment create --assignee $AKS_SP_ID --scope $AKS_VN_SUBNET_ID --role "Network Contributor"
az role assignment create --assignee $AKS_SP_ID --scope $APIM_HOSTED_SUBNET_ID --role "Network Contributor"

# You should include also all resources provisioned where AKS will be accessing via Azure RM
# You don't need to include Azure Container Registry as it can be assigned while creating the cluster

# Review the current SP assignments
az role assignment list --all --assignee $AKS_SP_ID --output json | jq '.[] | {"principalName":.principalName, "roleDefinitionName":.roleDefinitionName, "scope":.scope}'

#***** END Prepare Service Principal for AKS *****

echo "AAD AKS SP Scripts Execution Completed"