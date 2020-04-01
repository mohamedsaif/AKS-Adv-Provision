#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Making sure Azure Firewall CLI extension is installed on the subscription
az extension add -n azure-firewall


# We will need a Public IP for our Azure Firewall. let's create one
FW_PUBLIC_IP=$(az network public-ip create \
    -g $RG_INFOSEC \
    -n $FW_PIP_NAME \
    -l $LOCATION \
    --allocation-method static \
    --sku Standard \
    --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP)

# Or you can load an existing one to be reused
# FW_PUBLIC_IP=$(az network public-ip show -g $RG_INFOSEC-n $FW_PUBLICIP_NAME)

FW_PUBLIC_IP_ADDRESS=$(echo $FW_PUBLIC_IP | jq -r .publicIp.ipAddress)

# Creating new Azure Firewall
FW=$(az network firewall create \
    -g $RG_INFOSEC \
    -n $FW_NAME \
    -l $LOCATION \
    --tags $TAG_ENV_DEV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP)

# Capture existing Azure Firewall
# FW=$(az network firewall show -g $RG_INFOSEC-n $FW_NAME)

# Adding new firewall profile. This might take several mins:
# Note that vnet we are using has a subnet named (AzureFirewallSubnet) which is needed.
FW_IPCONFIG=$(az network firewall ip-config create \
    -f $FW_NAME \
    -n $FW_IPCONFIG_NAME \
    -g $RG_INFOSEC \
    --public-ip-address $FW_PUBLICIP_NAME \
    --vnet-name $HUB_EXT_VNET_NAME)

FW_PRIVATE_IP_ADDRESS=$(echo $FW_IPCONFIG | jq -r .privateIpAddress)

# If the IP Config already exists, you can use the (az network firewall show) stored in FW
# FW_PRIVATE_IP_ADDRESS=$(echo $FW | jq -r .ipConfigurations[0].privateIpAddress)
# echo $FW_PRIVATE_IP_ADDRESS

# Create UDR & Routing Table
# We need to force the traffic to go through the Azure Firewall private IP. That is why we need (User Defined Route "UDR" table)
az network route-table create -g $RG_INFOSEC--name $FW_UDR
az network route-table route create \
    -g $RG_INFOSEC\
    --name $FW_UDR_ROUTE_NAME \
    --route-table-name $FW_UDR \
    --address-prefix 0.0.0.0/0 \
    --next-hop-type VirtualAppliance \
    --next-hop-ip-address $FW_PRIVATE_IP_ADDRESS

# Restricting traffic dramatically improve security, but comes with a little bit of administration overhead :) which a fair tradeoff
# Remember a full updated list of rules can be found here: https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic

# Let's get the AKS outbound Public IP (that will be used to communicated outside the cluster)
AKS_PIP_ADDRESS=$(az network public-ip show -g $RG_AKS--name $AKS_PIP_NAME --query ipAddress -o tsv)

# Add Azure Firewall Network Rules
# Allow traffic from AKS Subnet to AKS API Server. Takes a about a min to create
# Keep in mind that the master nodes are fully managed and have assigned IP address the AKS managed service.
AKS_API_IP=$(kubectl get endpoints -o=jsonpath='{.items[?(@.metadata.name == "kubernetes")].subsets[].addresses[].ip}')

az network firewall network-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name 'aks-network-rules' \
    --name 'aks-api-nw-required' \
    --protocols 'TCP' \
    --source-addresses "*" \
    --destination-addresses $AKS_API_IP \
    --destination-ports 9000 22 443 \
    --action allow \
    --priority 200

# ntp.ubuntu.com for NTP time synchronization on Linux nodes
az network firewall network-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name 'aks-network-rules' \
    --name 'ntp-ubuntu-com' \
    --protocols 'UDP' \
    --source-addresses "*" \
    --destination-addresses 91.189.89.198 \
                            91.189.89.199 \
                            91.189.91.157 \
                            91.189.94.4 \
    --destination-ports 123

# If you need to allow access to Azure services, you can use service tags (You don't need to 
# specify destination IP addresses as it will be managed by Azure)

# Add Azure Firewall Application Rules
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name 'aks-app-rules' \
    -n 'app-required' \
    --source-addresses "*" \
    --protocols 'https=443' \
    --target-fqdns "${CONTAINER_REGISTRY_NAME}.azurecr.io" \
                   "*.azmk8s.io" "aksrepos.azurecr.io" \
                   "*.blob.core.windows.net" \
                   "mcr.microsoft.com" "*.cdn.mscr.io" \
                   "management.azure.com" \
                   "login.microsoftonline.com" \
                   "*.windowsupdate.com" \
                   "settings-win.data.microsoft.com" \
                   "*.ubuntu.com" \
                   "acs-mirror.azureedge.net" \
                   "*.docker.io" \
                   "production.cloudflare.docker.com" \
                   "*.events.data.microsoft.com" \
    --action allow \
    --priority 200

# The following FQDN / application rules are recommended for AKS clusters to function correctly:
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name 'aks-app-optional-rules' \
    -n 'app-sec-updates' \
    --source-addresses "*" \
    --protocols 'http=80' \
    --target-fqdns "security.ubuntu.com" "azure.archive.ubuntu.com" "changelogs.ubuntu.com" \
    --action allow \
    --priority 201

# The following FQDN / application rules are required for AKS clusters that have the Azure Monitor for containers enabled:
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name 'aks-app-optional-rules' \
    -n 'app-azure-monitor' \
    --source-addresses "*" \
    --protocols 'https=443' \
    --target-fqdns "dc.services.visualstudio.com" \
                   "*.ods.opinsights.azure.com" \
                   "*.oms.opinsights.azure.com" \
                   "*.monitoring.azure.com"
    # --action allow \ # Removed as we are adding it to existing colletion
    # --priority 200

# The following FQDN / application rules are required for Windows server based AKS clusters:
az network firewall application-rule create \
    -g $RG_INFOSEC\
    -f $FW_NAME \
    --collection-name 'aks-app-optional-rules' \
    -n 'app-windowsnodes' \
    --source-addresses "*" \
    --protocols 'https=443' 'http=80' \
    --target-fqdns "onegetcdn.azureedge.net" \
                   "winlayers.blob.core.windows.net" \
                   "winlayers.cdn.mscr.io" \
                   "go.microsoft.com" \
                   "mp.microsoft.com" \
                   "www.msftconnecttest.com" \
                   "ctldl.windowsupdate.com"
    # --action allow \
    # --priority 200

# Link the target subnet to the UDR to enforce the rules
az network vnet subnet update \
    -g $RG_INFOSEC\
    --vnet-name $HUB_EXT_VNET_NAME \
    --name $AKS_SUBNET_NAME \
    --route-table $FW_UDR

# Something went wrong, easily disable the route table enforcement via removing it from the subnet
az network vnet subnet update \
    -g $RG_INFOSEC\
    --vnet-name $HUB_EXT_VNET_NAME \
    --name $AKS_SUBNET_NAME \
    --remove routeTable

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

### Managing Asymmetric Routing
# Now with traffic originating from the AKS goes through the Firewall private IP, we still need to configure the routes coming into AKS through
# either a Load Balancer (public only) or through the Application Gateway. The default behavior will send the response through the Firewall
# not through the original address.
# Docs: https://docs.microsoft.com/en-us/azure/firewall/integrate-lb

# Adding a DNAT rule (Destination Network Address Translation)
# Adding a SNAT rule (Source Network Address Translation)
