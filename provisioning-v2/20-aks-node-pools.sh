#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

### AKS Node Pools
# Docs: https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools
# By default, an AKS cluster is created with a node-pool that can run Linux containers. 
# Node Pools can have a different AKS version, that is why it can be used to safely upgrade/update part of the cluster
# Also it can have different VM sizes and different OS (like adding Windows pool)
# Use az aks node-pool add command to add an additional node pool that can run Windows Server containers.
SECOND_NOODEPOOL=npstorage
az aks nodepool add \
    --resource-group $RG_AKS \
    --cluster-name $AKS_CLUSTER_NAME \
    --os-type Linux \
    --name $SECOND_NOODEPOOL \
    --node-count 3 \
    --max-pods 30 \
    --kubernetes-version $AKS_VERSION \
    --node-vm-size "Standard_DS2_v2" \
    --no-wait

# Additional parameters to consider

# If you want to control the scheduling to that pool, one way of doing it is via taints/toleration (hard constraint)
# --node-taints "osType=win:NoSchedule" \
# the above show an example of tainting the windows node pool so no linux workloads will be deployed (it is hard constraint)

# Enabling autoscaler for the node pool
# --enable-cluster-autoscaler \
#     --min-count 3 \
#     --max-count 5 \

# Operating system (Linux or Windows). helps create a Windows nodepool (require AKS v1.16+)
# --os-type Windows \

# (PREVIEW) Configuration subnet for the pool.
# --vnet-subnet-id $AKS_SUBNET_ID \

# Listing all node pools
az aks nodepool list --resource-group $RG_AKS --cluster-name $AKS_CLUSTER_NAME -o table

# You can use also kubectl to see all the nodes (across both pools when the new one finishes)
kubectl get nodes

# To configure a specific node pool (like configuring autoscaler options) you can use:
NODEPOOL_NAME=$SECOND_NOODEPOOL
az aks nodepool update \
    --resource-group $RG_AKS \
    --cluster-name $AKS_CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --update-cluster-autoscaler \
    --min-count 3 \
    --max-count 7

### Kubernetes native isolation of modes

# Now to avoid Kubernetes from scheduling nodes incorrectly to node pools, you need to use taints and toleration
# Example, when you have a Windows node pool, k8s can schedule linux pods their. What will happen then is the pod will
# never be able to start with error like "image operating system "linux" cannot be used on this platform"
# To avoid that, you can taint the Windows nodes with osType=win:NoSchedule
# Think of it like giving the windows node a bright color (aka taint) so only pods with tolerance for can be schedule there.

# If you need to update taint after the node pool creation, you can use the below kubectl command:
kubectl taint node aksnpwin000000 osType=win:NoSchedule
# Note: the problem with the above command, it is applied to a single node at a time and don't survive node upgrade (it is better to use --node-taints at the creation time)

# Another option is to use Node Pool taints during the creation of the node pool.
# Add the following configuration to the az aks nodepool create command:
# --node-taints "osType=win:NoSchedule"
# Node: You need Azure CLI 2.0.74 or higher.
# Note: Node Pool taint can't be changed after the node pool provisioning, at least for now.


# Delete a node pool
az aks nodepool delete \
    --resource-group $RG_AKS \
    --cluster-name $AKS_CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --no-wait

echo "AKS-Node-Pools Scripts Execution Completed"