#!/bin/bash

#***** Prepare User Managed Identity for AKS *****

# AKS Managed Identity
# Docs: https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#bring-your-own-control-plane-mi
# AKS provision Azure resources based on the cluster needs, 
# like automatic provision of storage or creating public load balancer
# Also AKS needs to communicate with AzureRM APIs through that MI

# AKS currently support 2 MI options: System (auto generated) and BYO User MI
# This scripts execute the BYO User MI

# Create a MI to be used by AKS 
# NOTE: (you should use this only once)
# NOTE: MI will be created in the central info sec RG
AKS_MI_NAME="${PREFIX}-aks-mi-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"
AKS_MI_AGENT_NAME="${PREFIX}-aks-agent-mi-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"

IS_NEW_MI=false
if [ "$AKS_MI_ID" == null ] || [ -z "$AKS_MI_ID" ]
then
    echo "New MI is needed"
    AKS_MI=$(az identity create --name $AKS_MI_NAME --resource-group $RG_INFOSEC)
    AKS_MI_AGENT=$(az identity create --name $AKS_MI_AGENT_NAME --resource-group $RG_INFOSEC)
    IS_NEW_MI=true
else
    echo "Existing MI is used"
fi

# As the json result stored in AKS_MI, we use some jq Kung Fu to extract the values 
# jq documentation: (https://shapeshed.com/jq-json/#how-to-pretty-print-json)
echo $AKS_MI | jq
AKS_MI_ID=$(echo $AKS_MI | jq -r .principalId)
echo $AKS_MI_ID
AKS_MI_RES_ID=$(echo $AKS_MI | jq -r .id)
echo $AKS_MI_RES_ID
# Save the new variables
# echo export AKS_MI=$AKS_MI_NAME >> ./$VAR_FILE
echo export AKS_MI_NAME=$AKS_MI_NAME >> ./$VAR_FILE
echo export AKS_MI_ID=$AKS_MI_ID >> ./$VAR_FILE
echo export AKS_MI_RES_ID=$AKS_MI_RES_ID >> ./$VAR_FILE

echo $AKS_MI_AGENT | jq
AKS_MI_AGENT_ID=$(echo $AKS_MI_AGENT | jq -r .principalId)
echo $AKS_MI_AGENT_ID
AKS_MI_AGENT_RES_ID=$(echo $AKS_MI_AGENT | jq -r .id)
echo $AKS_MI_AGENT_RES_ID
# Save the new variables
# echo export AKS_MI=$AKS_MI_NAME >> ./$VAR_FILE
echo export AKS_MI_AGENT_NAME=$AKS_MI_AGENT_NAME >> ./$VAR_FILE
echo export AKS_MI_AGENT_ID=$AKS_MI_AGENT_ID >> ./$VAR_FILE
echo export AKS_MI_AGENT_RES_ID=$AKS_MI_AGENT_RES_ID >> ./$VAR_FILE


### MI RBAC
# As we used --skip-assignment, we will be assigning the SP to various services later
# These assignment like ACR, vNET and other resources that will require AKS to access
# az role assignment create --assignee $AKS_MI_ID --scope <resourceScope> --role <role-name-or-id>

if [ "$IS_NEW_MI" = "true" ]
then
    echo "Assigning roles to new MI"

    # AKS Resource Group
    # I will give a contributor access on the resource group that holds directly provisioned resources used only by AKS
    RG_AKS_ID=$(az group show --name $RG_AKS --query id -o tsv)
    az role assignment create --assignee $AKS_MI_ID --scope $RG_AKS_ID --role "Contributor"

    # vNet RBAC
    
    # To avoid future permission issues, I can grant contributor on the spoke vnet level (usful if this vnet dedicated only to a project)
    az role assignment create --assignee $AKS_MI_ID --scope $PROJ_VNET_ID --role "Network Contributor"

    # Granular access (incase the spoke network is shared with other workloads)
    # NOTE: currently if you are using private clusters, you need network contributor on the vnet level (for private DNS link)

    # AKS_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $AKS_SUBNET_NAME --query id -o tsv)
    # AKS_SVC_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $SVC_SUBNET_NAME --query id -o tsv)
    # AKS_VN_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $VN_SUBNET_NAME --query id -o tsv)
    # APIM_HOSTED_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $APIM_HOSTED_SUBNET_NAME --query id -o tsv)
    # az role assignment create --assignee $AKS_MI_ID --scope $AKS_SUBNET_ID --role "Network Contributor"
    # az role assignment create --assignee $AKS_MI_ID --scope $AKS_SVC_SUBNET_ID --role "Network Contributor"
    # az role assignment create --assignee $AKS_MI_ID --scope $AKS_VN_SUBNET_ID --role "Network Contributor"
    # az role assignment create --assignee $AKS_MI_ID --scope $APIM_HOSTED_SUBNET_ID --role "Network Contributor"

    # Private DNS Zone (only for private clusters with BYO DNS Zone)
    # az role assignment create --assignee $AKS_MI_ID --scope $AKS_PRIVATE_DNS_ID --role "Private DNS Zone Contributor"

    # You should include also all resources provisioned where AKS will be accessing via Azure RM
    # You don't need to include Azure Container Registry as it can be assigned while creating the cluster

    # Agent pool assignment to ACR
    echo $CONTAINER_REGISTRY_ID
    az role assignment create --assignee $AKS_MI_AGENT_ID --scope $CONTAINER_REGISTRY_ID --role "AcrPull"

fi

# Review the current SP assignments
az role assignment list \
    --all \
    --assignee $AKS_MI_ID \
    --output json | jq '.[] | {"principalName":.principalName, "roleDefinitionName":.roleDefinitionName, "scope":.scope}'


# Kubelet identity
az role assignment list \
    --all \
    --assignee $AKS_MI_AGENT_ID \
    --output json | jq '.[] | {"principalName":.principalName, "roleDefinitionName":.roleDefinitionName, "scope":.scope}'


#***** END Prepare Service Principal for AKS *****

echo "User Managed Identity for AKS Scripts Execution Completed"