#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Notes about Azure Firewall:

# Azure Firewall is a cloud native network security service. It offers fully stateful network 
# and application level traffic filtering for VNet resources, with built-in high availability 
# and cloud scalability delivered as a service

# In this architecture, Azure Firewall is deployed in the hub, which provides an additional layer 
# of security. Azure Firewall is cost effective, especially if it's used as a shared solution 
# consumed by multiple workloads

# Many Azure customers find the Azure Firewall feature set is a good fit and it provides some key 
# advantages as a cloud native managed service.

# Using of Azure Firewall is optional. If you require the use of specific 3rd party firewall, then
# go ahead with the selection of a cloud native firewall or NVA
# Check a list of feature set of Azure Firewall vs. 3rd Party NVAs: https://azure.microsoft.com/en-us/blog/azure-firewall-and-network-virtual-appliances/

# Making sure Azure Firewall CLI extension is installed on the subscription
az extension add -n azure-firewall


# We will need a Public IP for our Azure Firewall. let's create one
FW_PUBLIC_IP=$(az network public-ip create \
    -g $RG_INFOSEC \
    -n $FW_PIP_NAME \
    -l $LOCATION \
    --allocation-method static \
    --sku Standard \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP)

# Or you can load an existing one to be reused
# FW_PUBLIC_IP=$(az network public-ip show -g $RG_INFOSEC-n $FW_PIP_NAME)

FW_PUBLIC_IP_ADDRESS=$(echo $FW_PUBLIC_IP | jq -r .publicIp.ipAddress)
echo $FW_PUBLIC_IP_ADDRESS
echo export FW_PUBLIC_IP_ADDRESS=$FW_PUBLIC_IP_ADDRESS >> ./$VAR_FILE

# Creating new Azure Firewall
FW=$(az network firewall create \
    -g $RG_INFOSEC \
    -n $FW_NAME \
    -l $LOCATION \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP)

# Capture existing Azure Firewall
# FW=$(az network firewall show -g $RG_INFOSEC-n $FW_NAME)

# Adding new firewall profile. This might take several mins:
# Note that vnet we are using has a subnet named (AzureFirewallSubnet) which is needed.
# This will create the public ip profile for the firewall
FW_IPCONFIG=$(az network firewall ip-config create \
    -f $FW_NAME \
    -n $FW_IPCONFIG_NAME \
    -g $RG_INFOSEC \
    --public-ip-address $FW_PIP_NAME \
    --vnet-name $HUB_EXT_VNET_NAME)

FW_PRIVATE_IP_ADDRESS=$(echo $FW_IPCONFIG | jq -r .privateIpAddress)
echo export FW_PRIVATE_IP_ADDRESS=$FW_PRIVATE_IP_ADDRESS >> ./$VAR_FILE

# If the IP Config already exists, you can use the (az network firewall show) stored in FW
# FW_PRIVATE_IP_ADDRESS=$(echo $FW | jq -r .ipConfigurations[0].privateIpAddress)
# echo $

# Create Routing Table
# We need to force the traffic to go through the Azure Firewall private IP. That is why we need (User Defined Route "UDR" table)
# Route will be 0.0.0.0/0 (all traffic) next hob is the Firewall private IP
az network route-table create -g $RG_INFOSEC --name $FW_UDR
az network route-table route create \
    -g $RG_INFOSEC\
    --name $FW_UDR_ROUTE_NAME \
    --route-table-name $FW_UDR \
    --address-prefix 0.0.0.0/0 \
    --next-hop-type VirtualAppliance \
    --next-hop-ip-address $FW_PRIVATE_IP_ADDRESS

# Restricting traffic dramatically improve security, but comes with a little bit of administration overhead :) which a fair tradeoff
# Remember a full updated list of rules can be found here: https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic

# Let's get the AKS outbound Public IP (that will be used to communicated outside the cluster).
# (PREVIEW) If you have AKS with userDefinedRout for outboundType, this will not work as AKS has no outbound Public IPs.
# (PREVIEW) AKS with userDefinedRoute needs the firewall provisioning before creating the cluster
AKS_OUTBOUND_PIP_ADDRESS=$(az network public-ip show -g $RG_AKS --name $AKS_PIP_NAME --query ipAddress -o tsv)
echo $AKS_OUTBOUND_PIP_ADDRESS
# Add Azure Firewall Network Rules

# | Collection                 | Rule Name                    | Source Addresses | Destination Addresses                                                                                                                                                               | Destination Ports | Protocol | Notes                                                                                                               |
# |----------------------------|------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------|----------|---------------------------------------------------------------------------------------------------------------------|
# | aks-required-network-rules | $AKS_CLUSTER_NAME-api        | *                | $AKS_API_IP                                                                                                                                                                         | 9000 22 443       | TCP      | Public AKS API Server                                                                                               |
# | aks-api-network-rules      | $AKS_CLUSTER_NAME-api-tunnel | *                | $AKS_API_IP                                                                                                                                                                         | 1194              | UDP      | for the tunnel front pod to  communicate with the tunnel  end on the public API server                              |
# | aks-api-network-rules      | $AKS_CLUSTER_NAME-api-dns    | *                | $AKS_API_IP                                                                                                                                                                         | 53                | UDP      | required if you have pods directly  accessing the public API server                                                 |
# | ubuntu-time-network-rules  | ntp-ubuntu-com               | *                | 91.189.89.198 91.189.89.199 91.189.91.157 91.189.94.4                                                                                                                               | 123               | UDP      | Time sync for Linux VMs                                                                                             |
# | aks-api-app-rules          | $AKS_CLUSTER_NAME-api        | *                | *.hcp.$LOCATION.azmk8s.io *.tun.$LOCATION.azmk8s.io                                                                                                                                 | https=443         |          | API Server communications                                                                                           |
# | azure-management-rules     | management-services          | *                | "mcr.microsoft.com" "*.data.mcr.microsoft.com" "management.azure.com" "login.microsoftonline.com" "packages.microsoft.com" "acs-mirror.azureedge.net"                               | https=443         |          | Accessing essential Azure services like  Microsoft Container Registry  Azure Management APIs Azure Active Directory |
# | azure-monitor-rules        | azure-monitor                | *                | "dc.services.visualstudio.com" "*.ods.opinsights.azure.com" "*.oms.opinsights.azure.com" "*.microsoftonline.com" "*.monitoring.azure.com"                                           | https=443         |          | Required for integration with Azure  Monitor services                                                               |
# | azure-services-rules       | service-tags                 | *                | "AzureContainerRegistry" "MicrosoftContainerRegistry" "AzureActiveDirectory"                                                                                                        | *                 | Any      | Allow connectivity to enabled  service tags                                                                         |
# | ubuntu-security-app-rules  | security-updates             | *                | "security.ubuntu.com" "azure.archive.ubuntu.com" "changelogs.ubuntu.com"                                                                                                            | http=80           |          | This address lets the Linux cluster nodes  download the required security patches and updates                       |
# | aks-azure-policy-app-rules | azure-policy                 | *                | "gov-prod-policy-data.trafficmanager.net" "raw.githubusercontent.com" "*.gk.${LOCATION}.azmk8s.io" "dc.services.visualstudio.com"                                                   | https=443         |          | This address is used for successful operation  of Azure Policy for AKS                                              |
# | aks-windows-app-rules      | app-windows-nodes            | *                | "onegetcdn.azureedge.net"  "winlayers.blob.core.windows.net"  "winlayers.cdn.mscr.io"  "go.microsoft.com"  "mp.microsoft.com"  "www.msftconnecttest.com"  "ctldl.windowsupdate.com" | http=80 https=443 |          | To install windows-related binaries                                                                                 |

# Allow traffic from AKS Subnet to AKS API Server. Takes a about a min to create
# Keep in mind that the master nodes are fully managed and have assigned IP address the AKS managed service.
# Note: Private Cluster don't need this as the traffic is internal in the vnet via private link
# Note: running the below command on private cluster will display a private ip of the AKS API server
AKS_API_IP=$(kubectl get endpoints -o=jsonpath='{.items[?(@.metadata.name == "kubernetes")].subsets[].addresses[].ip}')
echo $AKS_API_IP

### Network Rules

# Only create if you have a public AKS API server (not private). Here AKS cluster must be already up
# Warning: Sometime the public ip of the managed AKS API server might change. You need to update the rule when you detect that change.

# ONLY Public AKS
az network firewall network-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "aks-api-network-rules" \
    --name "${AKS_CLUSTER_NAME}-api" \
    --protocols "TCP" \
    --source-addresses "*" \
    --destination-addresses $AKS_API_IP \
    --destination-ports 9000 22 443 \
    --action allow \
    --priority 210

# ONLY Public AKS
az network firewall network-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "aks-api-network-rules" \
    --name "${AKS_CLUSTER_NAME}-api-tunnel" \
    --protocols "TCP" \
    --source-addresses "*" \
    --destination-addresses $AKS_API_IP \
    --destination-ports 1194 #\
    # --action allow \ # Removed as we are adding it to existing collection
    # --priority 210

# ONLY Public AKS
az network firewall network-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "aks-api-network-rules" \
    --name "${AKS_CLUSTER_NAME}-api-dns" \
    --protocols "UDP" \
    --source-addresses "*" \
    --destination-addresses $AKS_API_IP \
    --destination-ports 53 #\
    # --action allow \ # Removed as we are adding it to existing collection
    # --priority 210

# ntp.ubuntu.com for NTP time synchronization on Linux nodes 
# Note: VMs tends to drift over time of syncing is not enabled which might cause further issues
az network firewall network-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "ubuntu-time-network-rules" \
    --name "ntp-ubuntu-com" \
    --protocols "UDP" \
    --source-addresses "*" \
    --destination-addresses 91.189.89.198 \
                            91.189.89.199 \
                            91.189.91.157 \
                            91.189.94.4 \
    --destination-ports 123 \
    --action allow \
    --priority 220
# If you need to allow access to Azure services, you can use Private Link when supported or service tags (You don"t need to 
# specify destination IP addresses as it will be managed by Azure)
az network firewall network-rule create  \
    -g $RG_INFOSEC\
    --f $FW_NAME \
    --collection-name "azure-services-rules" \
    -n "service-tags" \
    --source-addresses "*" \
    --protocols "Any" \
    --destination-addresses "AzureContainerRegistry" "MicrosoftContainerRegistry" "AzureActiveDirectory" \
    --destination-ports "*" \
    --action "Allow" \
    --priority 230

### Application Rules

# ONLY Public AKS
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "aks-api-app-rules" \
    -n "${AKS_CLUSTER_NAME}-api" \
    --source-addresses "*" \
    --protocols "https=443" \
    --target-fqdns  "*.hcp.${LOCATION}.azmk8s.io" \
                    "*.tun.$LOCATION.azmk8s.io" \
    --action allow \
    --priority 210

# Add Azure Firewall Application Rules
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "azure-management-rules" \
    -n "management-services" \
    --source-addresses "*" \
    --protocols "https=443" \
    --target-fqdns  "mcr.microsoft.com" \
                    "*.data.mcr.microsoft.com" \
                    "management.azure.com" \
                    "login.microsoftonline.com" \
                    "packages.microsoft.com" \
                    "acs-mirror.azureedge.net" \
    --action allow \
    --priority 220

# The following FQDN / application rules are required for AKS clusters that have the Azure Monitor for containers enabled:
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "azure-monitor-rules" \
    -n "azure-monitor" \
    --source-addresses "*" \
    --protocols "https=443" \
    --target-fqdns "dc.services.visualstudio.com" \
                   "*.ods.opinsights.azure.com" \
                   "*.oms.opinsights.azure.com" \
                   "*.microsoftonline.com" \
                   "*.monitoring.azure.com" \
    --action allow \
    --priority 230

    # --action allow \ # Removed as we are adding it to existing colletion
    # --priority 200

# The following FQDN / application rules are recommended for AKS clusters  lets the Linux cluster nodes download the required security patches and updates:
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "ubuntu-security-app-rules" \
    -n "security-updates" \
    --source-addresses "*" \
    --protocols "http=80" \
    --target-fqdns "security.ubuntu.com" "azure.archive.ubuntu.com" "changelogs.ubuntu.com" \
    --action allow \
    --priority 240

# Enabling Azure Policy rules for AKS
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "aks-azure-policy-app-rules" \
    -n "azure-policy" \
    --source-addresses "*" \
    --protocols "https=443" \
    --target-fqdns "gov-prod-policy-data.trafficmanager.net" "raw.githubusercontent.com" "*.gk.${LOCATION}.azmk8s.io" "dc.services.visualstudio.com" \
    --action allow \
    --priority 250

# The following FQDN / application rules are required for Windows server based AKS clusters:
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "aks-windows-app-rules" \
    -n "app-windowsnodes" \
    --source-addresses "*" \
    --protocols "https=443" "http=80" \
    --target-fqdns "onegetcdn.azureedge.net" \
                   "winlayers.blob.core.windows.net" \
                   "winlayers.cdn.mscr.io" \
                   "go.microsoft.com" \
                   "mp.microsoft.com" \
                   "www.msftconnecttest.com" \
                   "ctldl.windowsupdate.com" \
    --action allow \
    --priority 260

# Pulling Images from container registry need to access bot the ACR and the associated Azure storage
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "container-registries-app-rules" \
    -n "${AKS_CLUSTER_NAME}-acr" \
    --source-addresses "*" \
    --protocols "https=443" \
    --target-fqdns "${CONTAINER_REGISTRY_NAME}.azurecr.io" "*.blob.core.windows.net" \
    --action allow \
    --priority 270

# OPTIONAL: Access to docker hub registry
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name "docker-hub-app-rules" \
    -n "docker" \
    --source-addresses "*" \
    --protocols "https=443" \
    --target-fqdns "*.docker.io" "production.cloudflare.docker.com" \
    --action allow \
    --priority 280

# OPTIONAL: Jump-box DNAT
# If you opted to create a private Jump-box so it will be accessed via the Azure Firewall IP, then you need DNAT rule
# Update the source-addresses to relect only the allowed IP ranges
az network firewall nat-rule create \
    -f $FW_NAME \
    -g $RG_INFOSEC \
    --collection-name jump-box \
    --name jump-box-inbound-ssh \
    --destination-addresses $FW_PIP_NAME \
    --destination-ports 22 \
    --protocols Any \
    --source-addresses '*' \
    --translated-port 22 \
    --translated-address $INSTALLER_PIP \
    --action Dnat \
    --priority 210

# Now we need to have the logs of the Firewall to monitor everything goes in/out
# Enable Azure Monitor for our firewall through creating a diagnostic setting
az monitor diagnostic-settings create \
    --resource $FW_NAME \
    --resource-group $RG_INFOSEC\
    --name $FW_NAME-logs \
    --resource-type "Microsoft.Network/azureFirewalls" \
    --workspace $HUB_EXT_WORKSPACE_NAME \
    --logs '[
        {
            "category": "AzureFirewallApplicationRule",
            "enabled": true,
            "retentionPolicy": {
                "enabled": false,
                "days": 30
            }
        },
        {
            "category": "AzureFirewallNetworkRule",
            "enabled": true,
            "retentionPolicy": {
                "enabled": false,
                "days": 30
            }
        }
    ]' \
    --metrics '[
        {
            "category": "AllMetrics",
            "enabled": true,
            "retentionPolicy": {
                "enabled": false,
                "days": 30
            }
        }
    ]'

# Now give it a few mins after first provision then head to the portal to get all nice graphs about the Firewall
# Follow the instruction here: https://docs.microsoft.com/en-us/azure/firewall/log-analytics-samples

# Finally, link the target subnet (AKS subnet) to the UDR to enforce the rules
AKS_SUBNET_ID=$(az network vnet subnet show -g $RG_SHARED --vnet-name $PROJ_VNET_NAME --name $AKS_SUBNET_NAME --query id -o tsv)
FW_UDR_ID=$(az network route-table show -g $RG_INFOSEC --name $FW_UDR --query id -o tsv)
az network vnet subnet update \
    --ids $AKS_SUBNET_ID \
    --route-table $FW_UDR_ID

# Something went wrong, easily disable the route table enforcement via removing it from the subnet
az network vnet subnet update \
    -g $RG_SHARED\
    --vnet-name $PROJ_VNET_NAME \
    --name $AKS_SUBNET_NAME \
    --remove routeTable

# Check egress (this pod will not be deployed as docker hub is not allowed)
# Add ubuntu image to ACR
# az acr import -n $CONTAINER_REGISTRY_NAME --source docker.io/library/ubuntu --image test/ubuntu:v1
# kubectl run -it --rm aks-ip --image=$CONTAINER_REGISTRY_NAME.azurecr.io/test/ubuntu:v1 --generator=run-pod/v1
# kubectl describe po aks-ip # ErrImagePull
# kubectl delete po aks-ip
# If suspend the firewall by removing the UDR from AKS subnet, you can proceed with the following tests
# apt-get update && apt-get install curl -y
# curl -s checkip.dyndns.org
# Denied execution:
# HTTP  request from 10.165.8.4:49274 to checkip.dyndns.org:80. Action: Deny. No rule matched. Proceeding with default action

### Managing Asymmetric Routing
# Now with traffic originating from the AKS goes through the Firewall private IP, we still need to configure the routes coming into AKS through
# either a Load Balancer (public only) or through the Application Gateway. The default behavior will send the response through the Firewall
# not through the original address.
# Docs: https://docs.microsoft.com/en-us/azure/fFW_PRIVATE_IP_ADDRESSirewall/integrate-lb
