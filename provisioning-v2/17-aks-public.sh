#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

#***** AKS Provisioning *****

# Have a look at the available versions first :)
az aks get-versions -l $LOCATION -o table

# To get the latest "production" supported version use the following (even if preview flag is activated):
AKS_VERSION=$(az aks get-versions -l ${LOCATION} --query "orchestrators[?isPreview==null].{Version:orchestratorVersion} | [-1]" -o tsv)
echo $AKS_VERSION

# Get latest AKS versions. 
# Note that this command will get the latest preview version if preview flag is activated)
# AKS_VERSION=$(az aks get-versions -l ${LOCATION} --query 'orchestrators[-1].orchestratorVersion' -o tsv)
# echo $AKS_VERSION

# Save the selected version
echo export AKS_VERSION=$AKS_VERSION >> ./$VAR_FILE

# Get the public IP for AKS outbound traffic
AKS_PIP_ID=$(az network public-ip show -g $RG_AKS --name $AKS_PIP_NAME --query id -o tsv)
echo "AKS PIP: " $AKS_PIP_ID
echo export AKS_PIP_ID=$AKS_PIP_ID >> ./$VAR_FILE
AKS_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $AKS_SUBNET_NAME --query id -o tsv)
echo "AKS Subnet: " $AKS_SUBNET_ID

# If you enabled the preview features above, you can create a cluster with these features (check the preview script)
# I separated some flags like --aad as it requires that you completed the preparation steps earlier
# Also note that some of these flags are not needed as I'm setting their default value, I kept them here
# so you can have an idea what are these values (especially the --max-pods per node which is default to 30)
# Check out the full list here https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create

# Be patient as the CLI provision the cluster :) maybe it is time to refresh your cup of coffee 
# or append --no-wait then check the cluster provisioning status via:
# az aks list -o table

# NOTE: address ranges for the subnet and cluster internal services are defined in variables script
# NOTE: Before executing the following commands, please consider reviewing the extended features below to append them if applicable
# NOTE: This creates ephemeral OS nodes, if you change the VM size, please make sure you are using a SKU that supports ephemeral disks
if [ "X$SHARED_WORKSPACE_ID" != "X" ]; then
 az aks create \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --location $LOCATION \
    --kubernetes-version $AKS_VERSION \
    --generate-ssh-keys \
    --outbound-type loadBalancer \
    --load-balancer-outbound-ips $AKS_PIP_ID \
    --vnet-subnet-id $AKS_SUBNET_ID \
    --network-plugin azure \
    --network-policy azure \
    --service-cidr $AKS_SERVICE_CIDR \
    --dns-service-ip $AKS_DNS_SERVICE_IP \
    --docker-bridge-address $AKS_DOCKER_BRIDGE_ADDRESS \
    --nodepool-name $AKS_DEFAULT_NODEPOOL \
    --node-count 3 \
    --max-pods 30 \
    --node-vm-size "Standard_D8s_v3" \
    --node-osdisk-type Ephemeral \
    --node-osdisk-size 170 \
    --vm-set-type VirtualMachineScaleSets \
    --enable-managed-identity \
    --assign-identity $AKS_MI_RES_ID \
    --attach-acr $CONTAINER_REGISTRY_NAME \
    --enable-addons monitoring \
    --workspace-resource-id $SHARED_WORKSPACE_ID \
    --enable-cluster-autoscaler \
    --min-count 1 \
    --max-count 3 \
    --zones 1 2 3 \
    --tags $TAG_ENV $TAG_PROJ_CODE $TAG_DEPT_IT $TAG_STATUS_EXP
else
 az aks create \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --location $LOCATION \
    --kubernetes-version $AKS_VERSION \
    --generate-ssh-keys \
    --enable-addons monitoring \
    --outbound-type loadBalancer \
    --load-balancer-outbound-ips $AKS_PIP_ID \
    --vnet-subnet-id $AKS_SUBNET_ID \
    --network-plugin azure \
    --network-policy azure \
    --service-cidr $AKS_SERVICE_CIDR \
    --dns-service-ip $AKS_DNS_SERVICE_IP \
    --docker-bridge-address $AKS_DOCKER_BRIDGE_ADDRESS \
    --nodepool-name $AKS_DEFAULT_NODEPOOL \
    --node-count 3 \
    --max-pods 30 \
    --node-vm-size "Standard_D8s_v3" \
    --node-osdisk-type Ephemeral \
    --node-osdisk-size 170 \
    --vm-set-type VirtualMachineScaleSets \
    --enable-managed-identity \
    --assign-identity $AKS_MI_RES_ID \
    --attach-acr $CONTAINER_REGISTRY_NAME \
    --enable-cluster-autoscaler \
    --min-count 1 \
    --max-count 3 \
    --zones 1 2 3 \
    --tags $TAG_ENV $TAG_PROJ_CODE $TAG_DEPT_IT $TAG_STATUS_EXP
fi

    # If you need to SP, replace the managed identity params with:
    # --service-principal $AKS_SP_ID \
    # --client-secret $AKS_SP_PASSWORD \

    # If you enabled aks-preview Azure CLI extension with version 0.3.2 or later, you can specify the custom name for the nodes resource group
    # By default, nodes resource group will be named [MC_resourcegroupname_clustername_location], to override it, add the following:
    # --node-resource-group $RG_AKS_NODES \

    # Using kubenet, you need to consider removing the subnet association and adding the pods cidr
    # --pod-cidr $AKS_POD_CIDR \

    # NOTE: based on your scenario, consider extending the command creation with:
    # # If you plan to use Windows Containers nodepools, you can provide the user name and password for the admin
    # --windows-admin-password $WIN_PASSWORD \
    # --windows-admin-username $WIN_USER \

    # If you have successfully created AAD integration with the admin consent, append these configs
    # --aad-server-app-id $SERVER_APP_ID \
    # --aad-server-app-secret $SERVER_APP_SECRET \
    # --aad-client-app-id $CLIENT_APP_ID \
    # --aad-tenant-id $TENANT_ID \

    # Enabling AKS cluster autoscaler
    # --enable-cluster-autoscaler \
    # --min-count 1 \
    # --max-count 5 \

    # It is worth mentioning that soon the AKS cluster will no longer heavily depend on Service Principal to access
    # Azure APIs, rather it will be done again through Managed Identity which is way more secure
    # The following configuration can be used while provisioning the AKS cluster to enabled Managed Identity
    # --enable-managed-identity

    # Note regarding network policy: the above provision we are enabling Azure Network Policy plugin, which is compliant with
    # Kubernetes native APIs. You can also use calico network policy (which work with kubenet and Azure CNI). Just update the
    # flag to use calico
    # --network-policy calico
    # Docs: https://docs.microsoft.com/en-us/azure/aks/use-network-policies

    # Check VMs that support ephemeral os disks (PowerShell)
    # $vmSizes=Get-AzComputeResourceSku | where{$_.ResourceType -eq 'virtualMachines' -and $_.Locations.Contains('WestEurope')}
    # foreach($vmSize in $vmSizes)
    # {
    #     foreach($capability in $vmSize.capabilities)
    #     {
    #         if($capability.Name -eq 'EphemeralOSDiskSupported' -and $capability.Value -eq 'true')
    #         {
    #             $vmSize
    #         }
    #     }
    # }
    # az vm list-usage -l 'westeurope' -o table
    # VM_SKUS=$(az vm list-skus -l 'westeurope' --output json)
    # echo $VM_SKUS | jq '.[] | {"Family":.family, "Name":.Standard_NC24rs_v2, "scope":.capabilities[?name=EphemeralOSDiskSupported]}'
    # echo "$VM_SKUS" | jq -c 'map( select( .capabilities[] | .name == "EphemeralOSDiskSupported" ))'
#***** END AKS Provisioning  *****

echo "AKS Scripts Execution Completed"
