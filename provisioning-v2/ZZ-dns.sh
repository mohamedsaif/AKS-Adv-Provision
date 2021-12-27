#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Check DNS resolution options on Microsoft docs: 
# https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances

# I will be using DNS conditional forwarding as the primary method of handling DNS queries
# In Hub network, a DNS Bind conditional forwarder will be deployed.
# I will assume the entire Azure services are using dedicated private domain name. 
# Like az-mohamedsaif.corp (must be not overlapping with on-premise domain names)

# I will override "Azure Provided" DNS at the spoke vnet level to point at the forwarder.
# Forwarder will white-list all private IP ranges 
# Forwarder will have the following forwarding zones:
# - zone for az-mohamedsaif.corp forwarding all requests to Azure Internal Resolver at 168.63.129.16
# - zone for azmk8s.io (AKS private end points DNS)
# - OPTIONAL: zones for any other related Azure managed private zones to Azure Internal Resolver at 168.63.129.16
# - OPTIONAL: zones for on-premise domain names to corporate DNS server

# For on-premise to Azure queries, the corporate DNS server will also have a conditional forwarding rule to the hub forwarder.

# NOTE: For forwarding the queries to Azure Internal Resolver from the hub network, you need to link all private dns zones to the hub vnet
# to be able to discover all Azure DNS private zones

# NOTE: Be aware that providing a custom DNS to your vnet, the internal.cloudapp.net suffix will not be supplied to your VMs as it might conflict with your other dns solution.
# You can runn the following on your VM nic, to retrieve the internal DNS assignment:
# DNS_NIC=dns-serverVMNIC
# az network nic show -g $RG_INFOSEC -n $DNS_NIC --query "dnsSettings.internalDomainNameSuffix"

# DNS Forwarder can be deployed using several options.
# Mainly here I'm focusing on Windows Server DNS or Bind on Ubuntu.
# If you want the visual interface and advance Active Directory integration, you might want to go with Windows Server
# Also deploying Bind (open source DNS solution) on Ubuntu is widely used as well.

# If found this link that might be helpful: 
# https://www.iguazio.com/docs-archive/intro/v2.1/setup/dns/
# https://www.digitalocean.com/community/tutorials/how-to-configure-bind-as-a-caching-or-forwarding-dns-server-on-ubuntu-14-04

# Windows Server DNS:
# - Create a Windows Server 2019 Data Center VM and deploy it to the Hub network in the DNS
# - Make sure that the Private IP assignment is static (DNS server IP should not change)
# - RDP to the dns-server and install "DNS Server" role
# - Open the "DNS Manager" to add your "Conditional Forwarder" rules (as per the above steps)
# - Update your on-premise DNS server to conditionally forward the traffic to this Forwarder (set conditions for Azure dedicated domain(s))
# - OPTIONAL: update your spoke vnet to point at the DNS Forwarder (if you want your spoke services to be able to communicate with on-premise DNS). Doing this might result in losing the VM to VM hostname discovery

# Bind9 DNS:
# Check https://github.com/Azure/azure-quickstart-templates/blob/master/301-dns-forwarder/forwarderSetup.sh

# NOTE: STILL UNDER DEVELOPMENT

# Now let's provision the Network Card for the DNS server

DNS_LB_NAME=hub-dns-lb-$SUBSCRIPTION_CODE-$LOCATION_CODE
DNS_LB_ID=$(az network lb create \
    -g $RG_INFOSEC \
    -n $DNS_LB_NAME \
    --sku Standard \
    --backend-pool-name "dns-servers" \
    --frontend-ip-name "dns-ip" \
    --private-ip-address $DNS_LB_IP \
    --subnet $DNS_SUBNET_ID \
    --query id -o tsv)

az network lb probe create \
    --resource-group $RG_INFOSEC \
    --lb-name $DNS_LB_NAME \
    --name dns-health-probe \
    --protocol tcp \
    --port 53

az network lb rule create \
    --backend-port 53 \
    --frontend-port 53 \
    --lb-name $DNS_LB_NAME \
    --name "dns-inbound" \
    --frontend-ip-name "dns-ip" \
    --backend-pool-name "dns-servers" \
    --protocol Udp \
    --resource-group $RG_INFOSEC \
    --probe-name dns-health-probe

# Creating one NIC and attached to the LB (you can repeat the process if needed)
DNS_VM_NAME="dns01-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"
DNS_VM_NIC="$DNS_VM_NAME-nic-${SUBSCRIPTION_CODE}-${LOCATION_CODE}"
DNS_SUBNET_ID=$(az network vnet subnet show -g $RG_INFOSEC --vnet-name $HUB_EXT_VNET_NAME --name $DNS_SUBNET_NAME --query id -o tsv)
az network nic create \
    -g $RG_INFOSEC \
    --subnet $DNS_SUBNET_ID \
    -n $DNS_VM_NIC \
    --private-ip-address $DNS_VM_NIC_IP \
    --lb-name $DNS_LB_NAME \
    --lb-address-pools "dns-servers"

# Retrieve NIC ID:
DNS_VM_NIC_ID=$(az network nic show \
    -g $RG_INFOSEC \
    -n $DNS_VM_NIC \
    --query id -o tsv)
echo $DNS_VM_NIC_ID

### Windows Server as DNS ###
# The below command will prompt for a password
az vm create \
    --resource-group $RG_INFOSEC \
    --name $DNS_VM_NAME \
    --image Win2019Datacenter \
    --nics $DNS_VM_NIC_ID \
    --admin-username azureuser \
    --public-ip-address ""

az vm open-port --port 53 --resource-group $RG_INFOSEC --name $DNS_VM_NAME

# To install DNS server feature in admin session of PowerShell:
Add-WindowsFeature 'DNS' -IncludeManagementTools

# Once you open the DNS Manager, you can see conditional forwarders section
# Add all private dns zones that where created and forward them to Azure DNS 168.63.129.16

# Examples of private zones assoicated with Azure Private link services:
# privatelink.azurecr.io
# privatelink.LOCATION.azmk8s.io

### Linux Server as DNS ###


echo export DNS_VM_NAME=$DNS_VM_NAME >> ./$VAR_FILE
echo export DNS_VM_NIC=$DNS_VM_NIC >> ./$VAR_FILE
echo export DNS_VM_NIC_ID=$DNS_VM_NIC_ID >> ./$VAR_FILE

echo "DNS Scripts Execution Completed"