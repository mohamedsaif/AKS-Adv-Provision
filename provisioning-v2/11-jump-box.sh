### OPTIONAL: Create an installation jump-box in AKS network
ssh-keygen -f ~/.ssh/installer-box-rsa -m PEM -t rsa -b 4096
# Get the ID for the masters subnet (as it is in a different resource group)
JUMPBOX_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $PROJ_DEVOPS_AGENTS_SUBNET_NAME --query id -o tsv)

# Create a resource group to host jump box

az group create \
    --name $RG_DEVOPS \
    --location $LOCATION \
    --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

INSTALLER_PIP=$(az vm create \
    --resource-group $RG_DEVOPS \
    --name installer-box \
    --image UbuntuLTS \
    --subnet $JUMPBOX_SUBNET_ID \
    --size "Standard_B2s" \
    --admin-username localadmin \
    --ssh-key-values ~/.ssh/installer-box-rsa.pub \
    --query publicIpAddress -o tsv)

echo export INSTALLER_PIP=$INSTALLER_PIP >> ./$VAR_FILE
# If you have an existing jumpbox, just set the public publicIpAddress
# INSTALLER_PIP=YOUR_IP

# SSH to the jumpbox
# ssh -i ~/.ssh/installer-box-rsa localadmin@$INSTALLER_PIP

# Installing Azure CLI
# curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Installing Kubectl via Azure CLI
# sudo az aks install-cli
# Or via apt-get
# sudo apt-get update && sudo apt-get install -y apt-transport-https
# echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
# sudo apt-get update
# sudo apt-get install -y kubectl

# Adding Azure DNS server (to handle the private name resolution)
# sudo chmod o+r /etc/resolv.conf

# Edit the DNS server name to use Azure's DNS server fixed IP 168.63.129.16 (press i to be in insert mode, then ESC and type :wq to save and exit)
# sudo vi /etc/resolv.conf

# Accessing AKS (private cluster)
# az login
# az account set --subscription REPLACE_SUBS_NAME_OR_ID
# az account show
# az aks get-credentials -n REPLACE_CLUSTER_NAME -g REPLACE_RESOURCE_GROUP
# test
# kubectl cluster-info
# kubectl get nodes