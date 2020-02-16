#!/bin/bash

# Make sure that variables are updated
source ~/.bashrc

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
echo export AKS_VERSION=$AKS_VERSION >> ~/.bashrc

# Get the public IP for AKS outbound traffic
AKS_PIP_ID=$(az network public-ip show -g $RG_AKS --name $AKS_PIP_NAME --query id -o tsv)

# If you enabled the preview features above, you can create a cluster with features like 
# the autoscaler, node pools,... 
# I separated some flags like --aad as it requires that you completed the preparation steps earlier
# Also note that some of these flags are not needed as I'm setting their default value, I kept them here
# so you can have an idea what are these values (especially the --max-pods per node which is default to 30)
# Check out the full list here https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create

# Be patient as the CLI provision the cluster :) maybe it is time to refresh your cup of coffee 
# or append --no-wait then check the cluster provisioning status via:
# az aks list -o table

# Note: address ranges for the subnet and cluster internal services are defined in variables script

# NOTE: Before executing the following commands, please consider reviewing the extended features below to append them if applicable
az aks create \
    --resource-group $RG_AKS \
    --node-resource-group $RG_AKS_NODES \
    --name $AKS_CLUSTER_NAME \
    --location $LOCATION \
    --kubernetes-version $AKS_VERSION \
    --generate-ssh-keys \
    --enable-addons monitoring \
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
    --node-vm-size "Standard_D4s_v3" \
    --vm-set-type VirtualMachineScaleSets
    --service-principal $AKS_SP_ID \
    --client-secret $AKS_SP_PASSWORD \
    --workspace-resource-id $SHARED_WORKSPACE_ID \
    --attach-acr $CONTAINER_REGISTRY_NAME \
    --tags $TAG_ENV_DEV $TAG_PROJ_CODE $TAG_DEPT_IT $TAG_STATUS_EXP

    # Using kubenet, you need to consider removing the subnet association and adding the pods cidr
    # --pod-cidr $AKS_POD_CIDR \

    # NOTE: based on your scenario, consider extending the command creation with:
    # If you have need this cluster Windows node pools capable, you need to provide
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

#***** END AKS Provisioning  *****

echo "AKS Scripts Execution Completed"