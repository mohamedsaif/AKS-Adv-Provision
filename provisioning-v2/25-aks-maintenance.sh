#!/bin/bash

# Make sure that variables are updated
source ./aks.vars

# This script go through the following:
# - AKS upgrade
# - Restarting nodes
# - AKS service principal rotation

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

### AAD integration with AKS maintenance

# Some time you need to rotate or update AKS AAD server and client applications.
# Doing that is just simple update command
az aks update-credentials \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --reset-aad \
    --aad-server-app-id <SERVER APPLICATION ID> \
    --aad-server-app-secret <SERVER APPLICATION SECRET> \
    --aad-client-app-id <CLIENT APPLICATION ID>

echo "AKS-Post-Provision Scripts Execution Completed"