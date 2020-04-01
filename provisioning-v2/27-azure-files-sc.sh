#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# You have 2 options to provision azure-files backed storage
# - Dynamic (through Storage Class)
# - Static

### Dynamic

# Simply add Azure-Files as storage class in your kubernetes.
# The following yaml deploy a new Standard_LRS storage class named "azurefile"
kubectl apply -f ./deployments/azure-file-sc.yaml

# AKS will provision the underlying storage account when a new deployment require storage specifying azurefile storage class

# Now to dynamically provision storage, you can refer: https://docs.microsoft.com/en-us/azure/aks/azure-files-dynamic-pv

# If you want to manually create a PVC, youse the following sample (some time you want for force use of ReadWriteMany mode):
# apiVersion: v1
# kind: PersistentVolumeClaim
# metadata:
#   name: aksshare-pvc
# spec:
#   accessModes:
#     - ReadWriteMany
#   storageClassName: azurefile
#   resources:
#     requests:
#       storage: 5Gi

# Then the pod uses that PVC, would look like:
# kind: Pod
# apiVersion: v1
# metadata:
#   name: mypod
# spec:
#   containers:
#   - name: mypod
#     image: nginx:1.15.5
#     resources:
#       requests:
#         cpu: 100m
#         memory: 128Mi
#       limits:
#         cpu: 250m
#         memory: 256Mi
#     volumeMounts:
#     - mountPath: "/mnt/azure"
#       name: volume
#   volumes:
#     - name: volume
#       persistentVolumeClaim:
#         claimName: azurefile

### Static

# The following steps, we create storage, create a secret to access the storage and then PV and PVC

# Set variables
AKS_PERS_STORAGE_ACCOUNT_NAME="${PREFIX}${SUBSCRIPTION_CODE}stg"
AKS_PERS_RESOURCE_GROUP=$RG_SHARED
AKS_PERS_LOCATION=$LOCATION
AKS_PERS_SHARE_NAME=${PREFIX}-aksshare

# Create a storage account
az storage account create -n $AKS_PERS_STORAGE_ACCOUNT_NAME -g $AKS_PERS_RESOURCE_GROUP -l $AKS_PERS_LOCATION --sku Standard_LRS

# Export the connection string as an environment variable, this is used when creating the Azure file share
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $AKS_PERS_STORAGE_ACCOUNT_NAME -g $AKS_PERS_RESOURCE_GROUP -o tsv)

# Create the file share
az storage share create -n $AKS_PERS_SHARE_NAME --connection-string $AZURE_STORAGE_CONNECTION_STRING

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
    --resource-group $AKS_PERS_RESOURCE_GROUP \
    --account-name $AKS_PERS_STORAGE_ACCOUNT_NAME \
    --query "[0].value" -o tsv)

# Echo storage account name and key
echo Storage account name: $AKS_PERS_STORAGE_ACCOUNT_NAME
echo Storage account key: $STORAGE_KEY

# Create Kubernetes secret to access the storage account
kubectl create secret generic askshare-secret \
    --from-literal=azurestorageaccountname=$AKS_PERS_STORAGE_ACCOUNT_NAME \
    --from-literal=azurestorageaccountkey=$STORAGE_KEY

# Sample mounting the created file-share above:
# apiVersion: v1
# kind: Pod
# metadata:
#   name: mypod
# spec:
#   containers:
#   - image: nginx:1.15.5
#     name: mypod
#     resources:
#       requests:
#         cpu: 100m
#         memory: 128Mi
#       limits:
#         cpu: 250m
#         memory: 256Mi
#     volumeMounts:
#       - name: askshare
#         mountPath: /mnt/azure
#   volumes:
#   - name: askshare
#     azureFile:
#       secretName: askshare-secret
#       shareName: [REPLACE with AKS_PERS_SHARE_NAME]
#       readOnly: false

echo "Azure Files storage class Scripts Execution Completed"