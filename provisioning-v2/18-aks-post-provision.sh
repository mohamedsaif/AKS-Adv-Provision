#!/bin/bash

# Make sure that variables are updated
source ~/.bashrc

# Connecting to AKS via kubectl
# append --admin on the below command if you enabled AAD as your account by default you don't have access
az aks get-credentials --resource-group $RG_AKS --name $AKS_CLUSTER_NAME

# Test the connection
kubectl get nodes

# You will get something like this:
# NAME                                STATUS   ROLES   AGE     VERSION
# aks-npdefault-20070408-vmss000000   Ready    agent   5m3s    v1.15.3
# aks-npdefault-20070408-vmss000001   Ready    agent   5m10s   v1.15.3
# aks-npdefault-20070408-vmss000002   Ready    agent   5m2s    v1.15.3

### Activate Azure Monitor for containers live logs
# Docs: https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-live-logs
kubectl apply -f ./deployments/monitoring-log-reader-rbac.yaml

# AAD enable cluster needs different configuration. Refer to docs above to get the steps

### AKS Policy via Azure Policy (Preview)
# Docs: https://docs.microsoft.com/en-us/azure/governance/policy/concepts/rego-for-aks
# you must complete the registration of the service mentioned earlier before executing this command
az aks enable-addons --addons azure-policy --name $AKS_CLUSTER_NAME --resource-group $RG

### AKS Auto Scaler (No node pools used)
# To update autoscaler configuration on existing cluster 
# Refer to documentation: https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler
# Note this is (without node pools). Previous script uses node pools so it wont' work
# az aks update \
#   --resource-group $RG_AKS \
#   --name $AKS_CLUSTER_NAME \
#   --update-cluster-autoscaler \
#   --min-count 1 \
#   --max-count 10

# To disable autoscaler on the entire cluster run aks update
# Use --no-wait if you don't wait for the operation to finish (run in the background)
# This will not work with node pools enabled cluster. Use the node pool commands later for that.
# az aks update \
#   --resource-group $RG_AKS \
#   --name $AKS_CLUSTER_NAME \
#   --disable-cluster-autoscaler

# After autoscaler disabled, you can use az aks scale to control the cluster scaling
# Add --nodepool-name if you are managing multiple node pools
# az aks scale --name $AKS_CLUSTER_NAME --node-count 3 --resource-group $RG

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

### AKS Upgrade
# Cluster Upgrade: https://docs.microsoft.com/en-us/azure/aks/upgrade-cluster
# Cluster with multiple node pools: https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools#upgrade-a-cluster-control-plane-with-multiple-node-pools
# Upgrading the cluster is a very critical process that you need to be prepared for
# AKS will support 2 minor versions previous to the current release

# First check for the upgrades
az aks get-upgrades \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    | jq

# Getting the latest production version of kubernetes (preview versions will not be returned even if the preview flag is on)
AKS_VERSION=$(az aks get-versions -l ${LOCATION} --query "orchestrators[?isPreview==null].{Version:orchestratorVersion} | [-1]" -o tsv)
echo $AKS_VERSION

# Note that this command will get the latest preview version only if preview flag is activated)
# AKS_VERSION=$(az aks get-versions -l ${LOCATION} --query 'orchestrators[-1].orchestratorVersion' -o tsv)
# echo $AKS_VERSION

# You can use az aks upgrade but will will upgrade the control plane and all node pools in the cluster.
az aks upgrade \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --kubernetes-version $AKS_VERSION
    --no-wait

# Now you can upgrade only the control plane for a better controlled upgrade process
az aks upgrade \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --kubernetes-version $AKS_VERSION
    --control-plane-only
    --no-wait

# After the control plane upgraded successfully, you can move with either in-place upgrade of each node pool or 
# do a Blue/Green upgrade where you provision a new node pool with the new version, move workloads from the existing pool
# through node selectors and labels. Delete all the old node pool once all workloads are drained.

# To upgrade a node pool
az aks nodepool upgrade \
    --resource-group $RG_AKS \
    --cluster-name $AKS_CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --kubernetes-version $AKS_VERSION \
    --no-wait


### Enable Virtual Nodes
# Docs: https://docs.microsoft.com/en-us/azure/aks/virtual-nodes-cli

# AKS can leverage Azure Container Instance (ACI) to expand the cluster capacity through on-demand provisioning
# of virtual nodes and pay per second for these expanded capacity
# Virtual Nodes are provisioned in the subnet to allow communication between Virtual Nodes and AKS nodes
# Check the above documentations for full details and the known limitations

# Make sure that you check the regional availability for this service in the documentation above.

# To use virtual nodes, you need AKS advanced networking enabled. Which we did
# Also we have setup a subnet to be used by virtual nodes and assigned access to AKS SP account.

# Make sure you have ACI provider registered
az provider list --query "[?contains(namespace,'Microsoft.ContainerInstance')]" -o table

# If not, you can register it now:
# az provider register --namespace Microsoft.ContainerInstance

# Now to activate it, you can execute the following command:
az aks enable-addons \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --addons virtual-node \
    --subnet-name $VNSUBNET_NAME

# Note: Virtual Nodes will not work with enabled cluster auto scaler on the (default node pool).
# You can disable it (if you got the error with this command)
# NODEPOOL_NAME=$AKS_DEFAULT_NODEPOOL
# az aks nodepool update \
#     --resource-group $RG_AKS \
#     --cluster-name $AKS_CLUSTER_NAME \
#     --name $NODEPOOL_NAME \
#     --disable-cluster-autoscaler

# Check again your available nodes
kubectl get nodes

# Below I have 3 nodes on the default pool, 1 windows node and a virtual node. Very powerful :)
# NAME                              STATUS   ROLES   AGE     VERSION
# aks-default-20070408-vmss000000   Ready    agent   13h     v1.15.3
# aks-default-20070408-vmss000001   Ready    agent   13h     v1.15.3
# aks-default-20070408-vmss000002   Ready    agent   13h     v1.15.3
# aksnpwin000000                    Ready    agent   101m    v1.15.3
# virtual-node-aci-linux            Ready    agent   2m13s   v1.13.1-vk-v0.9.0-1-g7b92d1ee-dev

# Later when you want to deploy on-demand service on the Virtual Nodes, you can use
# kubernetes nodeSelector and toleration in your deployment manifest like:
# nodeSelector:
#   kubernetes.io/role: agent
#   beta.kubernetes.io/os: linux
#   type: virtual-kubelet
# tolerations:
# - key: virtual-kubelet.io/provider
#   operator: Exists
# - key: azure.com/aci
#   effect: NoSchedule

# To disable Virtual Nodes:
az aks disable-addons --resource-group $RG_AKS --name $AKS_CLUSTER_NAME --addons virtual-node

# Container Registry Authentication for Virtual Nodes and ACI
# As basically virtual nodes are provisioned through ACI outside of the cluster, you need
# to setup your deployments/pods that target the virtual nodes with imagePullSecrets (as a workaround until full ACI integration with AKS SP or the use of managed identity go GA)

# You can use kubectl to create the secret :)
# Docs: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line
# kubectl create secret docker-registry acrImagePullSecret --docker-server=<your-acr-server> --docker-username=<sp id> --docker-password=<sp password> --docker-email=<optional email>

# You can inspect the secret easily via
# kubectl get secret acrImagePullSecret --output=yaml
# To have it in readable format use:
# kubectl get secret acrImagePullSecret --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode

# Finally, you need to update your deployment manifest under your container pod specs to use the imagePullSecrets:
# spec:
#   containers:
#   - name: <container-name>
#     image: <qualified image url on ACR>
#   imagePullSecrets:
#   - name: acrImagePullSecret

### AKS Nodes Restart
# As part of you upgrade strategy, node VMs OS sometime needs a restart (after a security patch install for example).
# Kured is an open source project that can support that process
# Docs: https://github.com/weaveworks/kured
# Kured (KUbernetes REboot Daemon) is a Kubernetes daemonset that performs safe automatic node reboots when the need 
# to do so is indicated by the package management system of the underlying OS.

# Deploying Kured to you cluster is a straight forward process (deployed to kured namespace):
kubectl apply -f https://github.com/weaveworks/kured/releases/download/1.2.0/kured-1.2.0-dockerhub.yaml

# If you wish to disable kured from restarting any nodes, you can run:
kubectl -n kube-system annotate ds kured weave.works/kured-node-lock='{"nodeID":"manual"}'

# Refer to the documentation on the link above to learn more

### Maintaining AKS Service Principal
# Docs: https://docs.microsoft.com/bs-latn-ba/azure/aks/update-credentials
# DON'T EXECUTE THESE SCRIPTS if you just provisioned your cluster. It is more about your long term strategy.
# From time to time (for example to be compliant with a security policy), you might need to update, reset or rotate
# AKS SP. Below are steps for resetting the password on existing cluster

# 1. Resetting the SP password

# Directly from AAD if you know the name
AKS_SP=$(az ad sp credential reset --name $AKS_SP_ID)

# OR from the AKS
AKS_SP_ID=$(az aks show --resource-group $RG_AKS --name $AKS_CLUSTER_NAME \
                --query servicePrincipalProfile.clientId -o tsv)
AKS_SP=$(az ad sp credential reset --name $AKS_SP_ID)

# Get the ID and Password
AKS_SP_ID=$(echo $AKS_SP | jq -r .appId)
AKS_SP_PASSWORD=$(echo $AKS_SP | jq -r .password)

echo $AKS_SP_ID
echo $AKS_SP_PASSWORD

# If you need to reset the SP for existing cluster use the following (takes a several moments of suspense =)
az aks update-credentials \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --reset-service-principal \
    --service-principal $AKS_SP_ID \
    --client-secret $AKS_SP_PASSWORD

# Troubleshooting note
# You got your cluster in (Failed State) don't panic
# You can check that the cluster APIs and worker nodes are still operational
# Just run az aks upgrade to restore state
az aks upgrade --resource-group $RG_AKS --name $AKS_CLUSTER_NAME --kubernetes-version $VERSION

#***** END AKS Provisioning  *****

echo "AKS-Post-Provision Scripts Execution Completed"