#!/bin/bash

# Make sure that variables are updated
source ./aks.vars

### AKS Node Pools
# Docs: https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools
# By default, an AKS cluster is created with a node-pool that can run Linux containers. 
# Node Pools can have a different AKS version, that is why it can be used to safely upgrade/update part of the cluster
# Also it can have different VM sizes and different OS (like adding Windows pool)
# Use az aks node-pool add command to add an additional node pool that can run Windows Server containers.
SECOND_NOODEPOOL=npwin
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

# Configuration subnet for the pool
# --vnet-subnet-id $AKS_SUBNET_ID \

# Operating system (Linux or Windows). Windows Required win enabled cluster
# --os-type Windows \

# When you create a pool, you want to control the scheduling to that pool, one of the hard way is using taints
# --node-taints "osType=win:NoSchedule"\
# the above show an example of tainting the windows node pool so no linux workloads will be deployed

# Enabling autoscaler
# --enable-cluster-autoscaler \
#     --min-count 3 \
#     --max-count 5 \

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
# Think of it like giving the windows node a bad smell (aka taint) so only pods with tolerance for can be schedule there.

kubectl taint node aksnpwin000000 osType=win:NoSchedule

# Problem with the above approach is you need to taint individual nodes.

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