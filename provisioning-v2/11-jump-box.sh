### OPTIONAL: Create an installation jump-box in AKS network
ssh-keygen -f ~/.ssh/installer-box-rsa -m PEM -t rsa -b 4096
# Get the ID for the masters subnet (as it is in a different resource group)
JUMPBOX_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $PROJ_DEVOPS_AGENTS_SUBNET_NAME --query id -o tsv)

# Create a resource group to host jump box

az group create --name $RG_DEVOPS --location $LOCATION

INSTALLER_PIP=$(az vm create \
    --resource-group $RG_DEVOPS \
    --name installer-box \
    --image UbuntuLTS \
    --subnet $JUMPBOX_SUBNET_ID \
    --size "Standard_B2s" \
    --admin-username localadmin \
    --ssh-key-values ~/.ssh/installer-box-rsa.pub \
    --query publicIpAddress -o tsv)

export INSTALLER_PIP=$INSTALLER_PIP >> ~/.bashrc
# If you have an existing jumpbox, just set the public publicIpAddress
# INSTALLER_PIP=YOUR_IP

# SSH to the jumpbox
ssh -i ~/.ssh/installer-box-rsa localadmin@$INSTALLER_PIP

# Installing Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Adding Azure DNS server (to handle the private name resolution)
sudo chmod o+r /etc/resolv.conf
# Edit the DNS server name to use Azure's DNS server fixed IP 168.63.129.16 (press i to be in insert mode, then ESC and type :wq to save and exit)
sudo vi /etc/resolv.conf