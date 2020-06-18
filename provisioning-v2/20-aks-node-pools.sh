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
    --mode system \
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

# System & User Node Pools
# Docs: https://docs.microsoft.com/en-us/azure/aks/use-system-pools
# Update existing node pool to user (or system):
az aks nodepool update -g $RG_AKS --cluster-name $AKS_CLUSTER_NAME -n $SECOND_NOODEPOOL --mode user

# Delete a node pool
az aks nodepool delete \
    --resource-group $RG_AKS \
    --cluster-name $AKS_CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --no-wait

# GPU node pool
# NOTE: these scripts assume that you have cloned the repo and currently running the commands on the context of ./provisioning-v2 folder
# Azure offers powerful N-series machines designed for AI, and Deep Learning workloads
# Check all avaialbe N-series SKUs: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-gpu
# Validate you have qouta of vCPUs to run N-series machines in the target location
az vm list-usage -l $LOCATION -o table | grep ' N'
# Locate all N-series machines (specially the ND and NC):
# Name                               CurrentValue    Limit  
# ---------------------------------  --------------  -------
# Standard NDS Family vCPUs          0               100
# Standard NCSv2 Family vCPUs        0               0
# Standard NCSv3 Family vCPUs        0               0
# If subscription don't have any limit available, you can submit a support request for increased quota.
# Check this guid to do so: https://github.com/mohamedsaif/IntelligentExperiences.OnContainers/tree/master/guide/00-setup#azure-subscription-limits

SECOND_NOODEPOOL=gpunodes
GPU_VM_SIZE=Standard_NC6
az aks nodepool add \
    --resource-group $RG_AKS \
    --cluster-name $AKS_CLUSTER_NAME \
    --os-type Linux \
    --name $SECOND_NOODEPOOL \
    --node-count 1 \
    --node-taints "type=gpu:NoSchedule" \
    --labels "accelerator=nvidia" \
    --max-pods 30 \
    --kubernetes-version $AKS_VERSION \
    --mode user \
    --node-vm-size $GPU_VM_SIZE

# Installing GPU drivers
# Docs: https://docs.microsoft.com/en-us/azure/aks/gpu-cluster
# Firewall notes: you need to have these allowed in order to install the extension
# https://dl.fedoraproject.org
# http://developer.download.nvidia.com
# https://developer.download.nvidia.com

kubectl create namespace gpu-resources

kubectl apply -f ./deployments/gpu-nvidia-device-plugin-ds.yaml

# Check deployed DaemonSet (I've configured it to run only on GPU nodes)
kubectl get all -n gpu-resources
kubectl get po -n gpu-resources -o wide

kubectl get nodes
kubectl describe node REPLACE_WITH_GPU_NODE_NAME
# Under capacity, you should see that you have 1+ GPU (depending on the VM size you selected)
# Capacity:
#   attachable-volumes-azure-disk:  24
#   cpu:                            6
#   ephemeral-storage:              129901008Ki
#   hugepages-1Gi:                  0
#   hugepages-2Mi:                  0
#   memory:                         57691052Ki
#   nvidia.com/gpu:                 1
#   pods:                           30

# Testing the GPU node via sample Tensorflow job against MNIST dataset (hand written digits with 60K training set)
kubectl apply -f ./deployments/gpu-samples-tf-mnist-demo.yaml

# Monitor the job progress to completion
kubectl get jobs samples-tf-mnist-demo --watch
# NAME                    COMPLETIONS   DURATION   AGE
# samples-tf-mnist-demo   0/1           7s         7s
# samples-tf-mnist-demo   1/1           2m1s       2m1s

# After completion of the job, get the pod name
kubectl get pods --selector app=samples-tf-mnist-demo -o wide
# NAME                          READY   STATUS      RESTARTS   AGE     IP           NODE                            
# samples-tf-mnist-demo-pq8rh   0/1     Completed   0          3m10s   10.42.1.83   aks-gpunodes-18277571-vmss000000

# Look at the description (specially node, Limits, Node-Selectors & Tolerations)
kubectl describe pod samples-tf-mnist-demo-pq8rh

# Get the logs of the execution
kubectl describe pod samples-tf-mnist-demo-pq8rh
# 2020-06-18 04:27:17.780570: I tensorflow/core/platform/cpu_feature_guard.cc:137] Your CPU supports instructions that this TensorFlow binary was not compiled to use: SSE4.1 SSE4.2 AVX AVX2 FMA
# 2020-06-18 04:27:17.901620: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1030] Found device 0 with properties: 
# name: Tesla K80 major: 3 minor: 7 memoryClockRate(GHz): 0.8235
# pciBusID: 0001:00:00.0
# totalMemory: 11.92GiB freeMemory: 11.85GiB
# 2020-06-18 04:27:17.901661: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1120] Creating TensorFlow device (/device:GPU:0) -> (device: 0, name: Tesla K80, pci bus id: 0001:00:00.0, compute capability: 3.7)
# 2020-06-18 04:27:22.535615: I tensorflow/stream_executor/dso_loader.cc:139] successfully opened CUDA library libcupti.so.8.0 locally
# Successfully downloaded train-images-idx3-ubyte.gz 9912422 bytes.
# Extracting /tmp/tensorflow/input_data/train-images-idx3-ubyte.gz
# Successfully downloaded train-labels-idx1-ubyte.gz 28881 bytes.
# Extracting /tmp/tensorflow/input_data/train-labels-idx1-ubyte.gz
# Successfully downloaded t10k-images-idx3-ubyte.gz 1648877 bytes.
# Extracting /tmp/tensorflow/input_data/t10k-images-idx3-ubyte.gz
# Successfully downloaded t10k-labels-idx1-ubyte.gz 4542 bytes.
# Extracting /tmp/tensorflow/input_data/t10k-labels-idx1-ubyte.gz
# Accuracy at step 0: 0.1001
# Accuracy at step 10: 0.7243
# Accuracy at step 20: 0.8315
# Accuracy at step 30: 0.8682
# Accuracy at step 40: 0.878
# Accuracy at step 50: 0.8922
# Accuracy at step 60: 0.9037
# [...]
# Adding run metadata for 99
# Accuracy at step 100: 0.916
# Accuracy at step 110: 0.914
# Accuracy at step 120: 0.9221
# Accuracy at step 130: 0.9213
# [...]
# Accuracy at step 480: 0.9547
# Accuracy at step 490: 0.9563
# Adding run metadata for 499

# Check out more scenarios at kubeflow-labs: https://github.com/Azure/kubeflow-labs

# Cleanup
kubectl delete -f ./deployments/gpu-samples-tf-mnist-demo.yaml

# Scale GPU nodepool down to zero when not in use:
# Note that you need at least 1 node pool with mode=system
az aks nodepool scale \
    --cluster-name $AKS_CLUSTER_NAME \
    --resource-group $RG_AKS \
    --name $SECOND_NOODEPOOL \
    --node-count 0 \
    --no-wait

# Or you can delete it completely
kubectl delete -f ./deployments/gpu-nvidia-device-plugin-ds.yaml
az aks nodepool delete -n gpunodes --resource-group $RG_AKS --cluster-name $AKS_CLUSTER_NAME

echo "AKS-Node-Pools Scripts Execution Completed"