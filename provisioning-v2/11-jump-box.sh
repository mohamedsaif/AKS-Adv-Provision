### OPTIONAL: Create an installation jump-box in AKS network
ssh-keygen -f ~/.ssh/installer-box-rsa -m PEM -t rsa -b 4096
# If you copied the ssh from another machine, you need to set permission on the private key
# chmod 600 ~/.ssh/id_rsa
# The above permission is needed if you recieve an error like:
# Permissions 0644 for '/.ssh/installer-box-rsa' are too open.
# It is required that your private key files are NOT accessible by others.
# This private key will be ignored.

# Get the ID for the masters subnet (as it is in a different resource group)
JUMPBOX_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $PROJ_DEVOPS_AGENTS_SUBNET_NAME --query id -o tsv)

# Create a resource group to host jump box

az group create \
    --name $RG_DEVOPS \
    --location $LOCATION \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP

# Creating a linux jump-box with public IP (for ease of access)
INSTALLER_PIP=$(az vm create \
    --resource-group $RG_DEVOPS \
    --name installer-box \
    --image UbuntuLTS \
    --subnet $JUMPBOX_SUBNET_ID \
    --public-ip-sku standard \
    --size "Standard_B2s" \
    --admin-username localadmin \
    --ssh-key-values ~/.ssh/installer-box-rsa.pub \
    --query publicIpAddress -o tsv)

# To create a jump-box with private IP and access from the Firewall Public IP,
# you can by creating a DNAT rule in the Azure Firewall to translate the detonation address to your jump-box
# Use --public-ip-address "" to avoid creating one (incase you will use it via the firewall).
# INSTALLER_PIP=$(az vm create \
#     --resource-group $RG_DEVOPS \
#     --name installer-box \
#     --image UbuntuLTS \
#     --subnet $JUMPBOX_SUBNET_ID \
#     --size "Standard_B2s" \
#     --public-ip-address "" \
#     --admin-username localadmin \
#     --ssh-key-values ~/.ssh/installer-box-rsa.pub \
#     --query privateIps -o tsv)

echo export INSTALLER_PIP=$INSTALLER_PIP >> ./$VAR_FILE
# If you have an existing jumpbox, just set the INSALLER_PIP with the correct one (direct public ip or through firewall)
# INSTALLER_PIP=YOUR_IP

# If you need to copy file(s) from the local machine (like vars file) to the jump-box, use the following command:
# Tar the provisioning-v2 folder (assuming this is the active folder now)
# tar -pvczf aks-provisioning-v2.tar.gz .
# scp -i ~/.ssh/installer-box-rsa ./aks-provisioning-v2.tar.gz localadmin@$INSTALLER_PIP:~/aks-provisioning-v2.tar.gz
# Or if you wish to copy only the variables file
# scp -i ~/.ssh/installer-box-rsa ./$VAR_FILE localadmin@$INSTALLER_PIP:~/$VAR_FILE

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

# Helm 3 Installation (https://helm.sh/docs/intro/install/)
# curl -sL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo bash

# Installing jq (for json KungFu in scripts)
# sudo apt-get install jq

# If you copied the provisioning script folder, untar it so you can use it
# mkdir aks-provisioning-v2
# tar -xvzf ./aks-provisioning-v2.tar.gz -C ./aks-provisioning-v2
# cd aks-provisioning-v2
# ls -l

# If you have copied the variables file, you can load it in the memory
# source ./REPLACE.vars
# Test values loaded successfully
# echo $RG_AKS

# If you didn't load the variable file, please replace all variables with values in the below commands

# Accessing AKS (private cluster)
# az login
# az account set --subscription $SUBSCRIPTION_ID
# az account show
# az aks get-credentials -n $AKS_CLUSTER_NAME -g $RG_AKS
# Testing
# Notice the API server private DNS
# kubectl cluster-info
# kubectl get nodes
# Use nslookup on the private DNS of the API Server (without https or port)
# Private DNS will looklike CLUSTER_NAME-RANDOM.GUID.privatelink.REGION.azmk8s.io
# Get AKS API server URL
# AKS_FQDN=$(az aks show -n $AKS_CLUSTER_NAME -g $RG_AKS --query 'privateFqdn' -o tsv)
# echo $AKS_FQDN
# nslookup $AKS_FQDN

# You might also want to have access to the provisioning scripts
# Either to copy them like what you did with the variable files (you can compress the folder then upload it)

# Troubleshooting
# (Failure of DNS resolution)
# Adding Azure DNS server explicitly (to handle the private name resolution)
# sudo chmod o+r /etc/resolv.conf
# Edit the DNS server name to use Azure's DNS server fixed IP 168.63.129.16 (press i to be in insert mode, then ESC and type :wq to save and exit)
# sudo vi /etc/resolv.conf
