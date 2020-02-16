#!/bin/bash

# Make sure that variables are updated
source ~/.bashrc

# This script go through the following:
# - Connecting to AKS
# - Live monitoring entablement
# - AKS autoscaler
# - AKS Virtual Nodes

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

echo "AKS-Post-Provision Scripts Execution Completed"