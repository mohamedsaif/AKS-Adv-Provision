#Set some variables
PREFIX="aksadv"
RG="${PREFIX}-rg"
RG_NODES="${RG}-nodes";
LOCATION="westeurope"
CLUSTER_NAME="${PREFIX}-mosaif-gbb"
CONTAINER_REGISTRY_NAME="${PREFIX}mosaifgbbacr"
WIN_USER="localwinadmin"
WIN_PASSWORD="P@ssw0rd1234"

#If you wish to have these valuse presist across sessions use:
echo export PREFIX=$PREFIX >> ~/.bashrc
echo export RG=$RG >> ~/.bashrc
echo export RG_NODES=$RG_NODES >> ~/.bashrc
echo export LOCATION=$LOCATION >> ~/.bashrc
echo export CLUSTER_NAME=$CLUSTER_NAME >> ~/.bashrc
echo export CONTAINER_REGISTRY_NAME=$CONTAINER_REGISTRY_NAME >> ~/.bashrc
echo export WIN_USER=$WIN_USER >> ~/.bashrc
echo export WIN_PASSWORD=$WIN_PASSWORD >> ~/.bashrc

# Makesur the script folder is the active one:
cd provisioning

# TIP: to persist variables for later sessions or in case of timeout
# echo export rg=$RG >> ~/.bashrc
# TIP: Making json output a little readable in echo use the following:
# alias prettyjson="python -m json.tool"
# echo '{"foo": "lorem", "bar": "ipsum"}' | prettyjson
# or use jq for even more color :)
# echo '{"foo": "lorem", "bar": "ipsum"}' | jq .
# TIP: Using aliases would make the commands typing much easier.
# alias k=kubectl
# alias kdev="kubectl --namespace=dev"
# Above aliases will be only available in the scope of the session. To make permenant assignment, store the alias in the ~/.bashrc
# You can use vim to edit and locate a seccion where vairous default aliases where defined
# vim ~/.bashrc

# Preparation
# Make sure you have the latest version of Azure CLI. 
# Azure CLI Installation: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
# I used Ubuntu on Windows Subsystem for Linux (WSL)
# The blow commands where executed agains:
# kubectl version -> v1.15.3
# Azure CLI -> 2.0.73
# If you have it installed already, maybe run an update command (this update everything :):
# Grab a drink as this would take several mins
# sudo apt-get update && sudo apt-get upgrade

#***** Login to Azure Subscription *****
# A browser window will open to complete the authentication :)
az login

# You can also login using Service Principal (replace values in <>)
# az login --service-principal --username APP_ID --password PASSWORD --tenant TENANT_ID

az account set --subscription "YOUR-SUBSCRIPTION-NAME"

#Make sure the active subscription is set correctly
SUBSCRIPTION_ACCOUNT=$(az account show)
echo $SUBSCRIPTION_ACCOUNT

# Get the tenant ID
TENANT_ID=$(echo $SUBSCRIPTION_ACCOUNT | jq -r .tenantId)
# or use TENANT_ID=$(az account show --query tenantId -o tsv)
echo $TENANT_ID
echo export TENANT_ID=$TENANT_ID >> ~/.bashrc

# Get the subscription ID
SUBSCRIPTION_ID=$(echo $SUBSCRIPTION_ACCOUNT | jq -r .id)
# or use TENANT_ID=$(az account show --query tenantId -o tsv)
echo $SUBSCRIPTION_ID
echo export SUBSCRIPTION_ID=$SUBSCRIPTION_ID >> ~/.bashrc

clear

#***** END Login to Azure Subscription *****

#***** Enable Preview Features of AKS *****

# Important: Enabling preview features of AKS takes effect at the subscription level. I advise that you enable these only on non-production subscription as
# it may alter the default behavior of some of the CLI commands and/or serives in scope

# Enable aks preview features (like autoscaler) through aks-preview Azure CLI extension
az extension add --name aks-preview

# If you already enabled the aks-preview extension before, make sure you are using the latest version
az extension list

# If the version is not per the required features, execute update instead of add
# At the time of writing this, version was 0.4.14
az extension update --name aks-preview

# Register multi agent pool. Docs: https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools#before-you-begin
az feature register --name MultiAgentpoolPreview --namespace Microsoft.ContainerService

#Register VMSS preview resource provider at the subscription level
az feature register --name VMSSPreview --namespace Microsoft.ContainerService

# Register Standar Load Balancer SKU as the default instead of the basic load balancer
az feature register --name AKSAzureStandardLoadBalancer --namespace Microsoft.ContainerService

# Register Windows Containers preview features which will allow creating a Node Pool that will run windows containers in your AKS cluster
# Read more about the features and limitations here: https://docs.microsoft.com/en-us/azure/aks/windows-container-cli
az feature register --name WindowsPreview --namespace Microsoft.ContainerService

# Limit egress traffic for cluster nodes and control access to required ports and services in Azure Kubernetes Service (AKS)
az feature register --name AKSLockingDownEgressPreview --namespace Microsoft.ContainerService

# Use Azure Managed Identity with the AKS cluster
# There are few limitations that will still require a SP to use with various features like storage provisioning
az feature register --name MSIPreview --namespace Microsoft.ContainerService

# As the new resource provider takes time (several mins) to register, you can check the status here. Wait for the state to show "Registered"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/MultiAgentpoolPreview')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKSAzureStandardLoadBalancer')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/WindowsPreview')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKSLockingDownEgressPreview')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/MSIPreview')].{Name:name,State:properties.state}"

# After registrations finish with status "Registered", you can update the provider
az provider register --namespace Microsoft.ContainerService

#***** END Enable Preview Features of AKS *****

#***** Prepare Service Principal for AKS *****

# AKS Service Principal
# Docs: https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/aks/kubernetes-service-principal.md
# AKS provision Azure resources based on the cluster needs, 
# like automatic provision of storage or creating public load balancer
# Also AKS needs to communicate with AzureRM APIs through that SP
# You can use the automatically generated SP if you omitted the SP configuration in AKS creation process

# Create a SP to be used by AKS
AKS_SP_NAME="${PREFIX}-aks-sp"
AKS_SP=$(az ad sp create-for-rbac -n $AKS_SP_NAME --skip-assignment)
# As the json result stored in AKS_SP, we use some jq Kung Fu to extract the values 
# jq documentation: (https://shapeshed.com/jq-json/#how-to-pretty-print-json)
echo $AKS_SP | jq
AKS_SP_ID=$(echo $AKS_SP | jq -r .appId)
AKS_SP_PASSWORD=$(echo $AKS_SP | jq -r .password)
echo $AKS_SP_ID
echo $AKS_SP_PASSWORD

# OR you can retrive back existing SP any time:
# AKS_SP=$(az ad sp show --id http://$AKS_SP_NAME)
# AKS_SP_ID=$(echo $AKS_SP | jq -r .appId)
# AKS_SP_PASSWORD="REPLACE_SP_PASSWORD"

# Don't have the password, get new password for SP (careful not to void in-use SP account)
# AKS_SP=$(az ad sp credential reset --name $AKS_SP_ID)
# AKS_SP_ID=$(echo $AKS_SP | jq -r .appId)
# AKS_SP_PASSWORD=$(echo $AKS_SP | jq -r .password)
# echo $AKS_SP_ID
# echo $AKS_SP_PASSWORD

# Save the new vairables
echo export AKS_SP_NAME=$AKS_SP_NAME >> ~/.bashrc
echo export AKS_SP_ID=$AKS_SP_ID >> ~/.bashrc
echo export AKS_SP_PASSWORD=$AKS_SP_PASSWORD >> ~/.bashrc

# Get also the AAD object id for the SP for later use
AKS_SP_OBJ_ID=$(az ad sp show --id ${AKS_SP_ID} --query objectId -o tsv)
echo $AKS_SP_OBJ_ID
echo export AKS_SP_OBJ_ID=$AKS_SP_OBJ_ID >> ~/.bashrc

# As we used --skip-assignment, we will be assigning the SP to various services later
# These assignment like ACR, vNET and other resources that will require AKS to access
# az role assignment create --assignee $AKS_SP_ID --scope <resourceScope> --role Contributor

# To update existing AKS cluster SP, use the following command (when needed):
# az aks update-credentials \
#     --resource-group $RG \
#     --name $CLUSTER_NAME \
#     --reset-service-principal \
#     --service-principal $AKS_SP_ID \
#     --client-secret $AKS_SP_PASSWORD

#***** END Prepare Service Principal for AKS *****

#***** Prepare AAD for AKS *****

### AKS AAD Prerequiestes
# Further documentation can be found here https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli

# If AAD Enabled Cluster is needed, you need to configure that before cluster creation
# A lot of organization restrict access to the AAD tenant, 
# you can ask the Azure AD Tenant Administrator to perform the below actions
# Remember that AAD authentication is for USERS not systems :)
# Also you can't enable AAD on an existing AKS cluster
# I used my own subscription and AAD Tenant, so I was the tenant admin :)

# Create the Azure AD application to act as identity endpoint for the identity requests
SERVER_APP_ID=$(az ad app create \
    --display-name "${CLUSTER_NAME}-server" \
    --identifier-uris "https://${CLUSTER_NAME}-server" \
    --query appId -o tsv)
echo $SERVER_APP_ID

# Update the application group memebership claims
az ad app update --id $SERVER_APP_ID --set groupMembershipClaims=All

# Create a service principal for the Azure AD app to use it to authenticate itself
az ad sp create --id $SERVER_APP_ID

# Get the service principal secret through reset :) This will work also with exising SP
SERVER_APP_SECRET=$(az ad sp credential reset \
    --name $SERVER_APP_ID \
    --credential-description "AKSPassword" \
    --query password -o tsv)
echo $SERVER_APP_SECRET

# Assigning permissions for readying directory, sign in and read user profile data to SP
az ad app permission add \
    --id $SERVER_APP_ID \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role

# Now granting them. Expect "Frobidden" error if you are not Azure tenant admin :(
az ad app permission grant --id $SERVER_APP_ID --api 00000003-0000-0000-c000-000000000000
# As we need Raad All data, we require the admin consent (this require AAD tenant admin)
# Azure tenant admin can login to AAD and grant this from the portal
az ad app permission admin-consent --id  $SERVER_APP_ID

### Client AAD Setup (like when a user connects ursing kubectl)

# Create new AAD app
CLIENT_APP_ID=$(az ad app create \
    --display-name "${CLUSTER_NAME}-client" \
    --native-app \
    --reply-urls "https://${CLUSTER_NAME}-client" \
    --query appId -o tsv)
echo $CLIENT_APP_ID

# Creation SP for the client
az ad sp create --id $CLIENT_APP_ID

# We need the OAuth token from the server app created in the prvious step. This will allow authentication flow between the two app components
OAUTH_PREMISSION_ID=$(az ad app show --id $SERVER_APP_ID --query "oauth2Permissions[0].id" -o tsv)

# Adding and granting OAuth flow between the server and client apps
az ad app permission add --id $CLIENT_APP_ID --api $SERVER_APP_ID --api-permissions $OAUTH_PREMISSION_ID=Scope

# Again with the "Forbidden" error if you are not Azure tenant admin
az ad app permission grant --id $CLIENT_APP_ID --api $SERVER_APP_ID

#***** END Prepare AAD for AKS *****

#***** AKS Resource Group and Networking *****

# 1. Resource Groups
# 2. vNet
# 3. Public IP

# 1. Create new resource group
az group create --name $RG --location $LOCATION

# 2. vNET Provisioing
# Please note that networking address space requires careful design excersise that you should go through. 
# For simplicity I'm using /16 for the address space with /24 for each service
VNET_NAME="${PREFIX}-vnet"
AKSSUBNET_NAME="${PREFIX}-akssubnet"
SVCSUBNET_NAME="${PREFIX}-svcsubnet"
AGW_SUBNET_NAME="${PREFIX}-appgwsubnet"
FWSUBNET_NAME="${PREFIX}-fwsubnet"
VNSUBNET_NAME="${PREFIX}-vnsubnet"

# First we creat the vNet with default AKS subnet
# Always carefully plan your network size
# Sizing docs: https://docs.microsoft.com/en-us/azure/aks/configure-azure-cni
az network vnet create \
    --resource-group $RG \
    --name $VNET_NAME \
    --address-prefixes 10.42.0.0/16 \
    --subnet-name $AKSSUBNET_NAME \
    --subnet-prefix 10.42.1.0/24

# Create subnet for kubernetes exposed services (usually by internal loadbalancer)
# Good security practice to isolate exposed services from the internal services
az network vnet subnet create \
    --resource-group $RG \
    --vnet-name $VNET_NAME \
    --name $SVCSUBNET_NAME \
    --address-prefix 10.42.2.0/24

# Create subnet for App Gateway
az network vnet subnet create \
    --resource-group $RG \
    --vnet-name $VNET_NAME \
    --name $AGW_SUBNET_NAME \
    --address-prefix 10.42.3.0/24

# Create subnet for Azure Firewall
az network vnet subnet create \
    --resource-group $RG \
    --vnet-name $VNET_NAME \
    --name $FWSUBNET_NAME \
    --address-prefix 10.42.4.0/24

# Create subnet for Virtual Nodes
az network vnet subnet create \
    --resource-group $RG \
    --vnet-name $VNET_NAME \
    --name $VNSUBNET_NAME \
    --address-prefix 10.42.5.0/24

# Get the Azure IDs the vNet and AKS Subnet for use with AKS SP role assignment
VNET_ID=$(az network vnet show -g $RG --name $VNET_NAME --query id -o tsv)
AKS_SUBNET_ID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME --name $AKSSUBNET_NAME --query id -o tsv)
AKS_SVCSUBNET_ID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME --name $SVCSUBNET_NAME --query id -o tsv)
AKS_AGWSUBNET_ID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME --name $AGW_SUBNET_NAME --query id -o tsv)
AKS_FWSUBNET_ID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME --name $FWSUBNET_NAME --query id -o tsv)
AKS_VNSUBNET_ID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME --name $VNSUBNET_NAME --query id -o tsv)

# Make sure that IDs set correctly
echo $VNET_ID
echo $AKS_SUBNET_ID
echo $AKS_SVCSUBNET_ID
echo $AKS_AGWSUBNET_ID
echo $AKS_FWSUBNET_ID
echo $AKS_VNSUBNET_ID

# Saving values
echo export VNET_NAME=$VNET_NAME >> ~/.bashrc
echo export SVCSUBNET_NAME=$SVCSUBNET_NAME >> ~/.bashrc
echo export VNET_ID=$VNET_ID >> ~/.bashrc
echo export AKS_SUBNET_ID=$AKS_SUBNET_ID >> ~/.bashrc
echo export AKS_SVCSUBNET_ID=$AKS_SVCSUBNET_ID >> ~/.bashrc
echo export AKS_AGWSUBNET_ID=$AKS_AGWSUBNET_ID >> ~/.bashrc
echo export AKS_FWSUBNET_ID=$AKS_FWSUBNET_ID >> ~/.bashrc
echo export AKS_VNSUBNET_ID=$AKS_VNSUBNET_ID >> ~/.bashrc

# Before we forget, assign AKS SP to the vnet
# Granular permission also can be granted through the Network Contributor role
# Docs: https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/role-based-access-control/built-in-roles.md#network-contributor
az role assignment create --assignee $AKS_SP_ID --scope $AKS_SUBNET_ID --role "Network Contributor"
az role assignment create --assignee $AKS_SP_ID --scope $AKS_SVCSUBNET_ID --role "Network Contributor"
az role assignment create --assignee $AKS_SP_ID --scope $AKS_VNSUBNET_ID --role "Network Contributor"

# If you wish to save time (not recommended for production), you can give the SP contributor on the vNet :) with 1 line
az role assignment create --assignee $AKS_SP_ID --scope $VNET_ID --role "Contributor"

# 3. Public IP

# Provision a standard public IP
AKS_PIP_NAME="${PREFIX}-aks-pip"
AKS_PIP=$(az network public-ip create -g $RG --name $AKS_PIP_NAME --sku Standard)
echo $AKS_PIP | jq

# I'm geting the Public IP from Azure rather than using jq on $AKS_PIP for demonstration on geting existing PIP
AKS_PIP_ID=$(az network public-ip show -g $RG --name $AKS_PIP_NAME --query id -o tsv)
echo $AKS_PIP_ID

# Saving value
echo export AKS_PIP_ID=$AKS_PIP_ID >> ~/.bashrc

# Review the current SP assignments
az role assignment list --all --assignee $AKS_SP_ID --output json | jq '.[] | {"principalName":.principalName, "roleDefinitionName":.roleDefinitionName, "scope":.scope}'

#***** END AKS Resource Group and Networking *****

#***** AKS Provisioning *****

# Have a look at the avaialbe versions first :)
az aks get-versions -l ${LOCATION} -o table

# Get latest AKS versions (note that this command will get the latest preview version if preview flag is activated)
AKS_VERSION=$(az aks get-versions -l ${LOCATION} --query 'orchestrators[-1].orchestratorVersion' -o tsv)
echo $AKS_VERSION

# To get the latest production supported version use the following (even if preview flag is activated):
AKS_VERSION=$(az aks get-versions -l ${LOCATION} --query "orchestrators[?isPreview==null].{Version:orchestratorVersion} | [-1]" -o tsv)
echo $AKS_VERSION

# Save the selected version
echo export AKS_VERSION=$AKS_VERSION >> ~/.bashrc

# Giving a friendly name to our default node pool
AKS_DEFAULT_NODEPOOL=npdefault

# If you enabled the preview features above, you can create a cluster with features like 
# the autosclaer, node pools,... 
# I separated some flags like --aad as it requires that you completed the prepartion steps earlier
# Also note that some of these flags are not needed as I'm setting their default value, I kept them here
# so you can have an idea what are these values (espeically the --max-pods per node which is default to 30)
# Check out the full list here https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create

# Be patient as the CLI provision the cluster :) maybe it is time to refresh your cup of coffee 
# or append --no-wait then check the cluster provisining status via:
# az aks list -o table

az aks create \
    --resource-group $RG \
    --node-resource-group $RG_NODES \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --kubernetes-version $AKS_VERSION \
    --generate-ssh-keys \
    --enable-addons monitoring \
    --load-balancer-sku standard \
    --load-balancer-outbound-ips $AKS_PIP_ID \
    --network-plugin azure \
    --network-policy azure \
    --service-cidr 10.41.0.0/16 \
    --dns-service-ip 10.41.0.10 \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id $AKS_SUBNET_ID \
    --nodepool-name $AKS_DEFAULT_NODEPOOL \
    --node-count 3 \
    --max-pods 30 \
    --node-vm-size "Standard_B2s" \
    --enable-vmss \
    --enable-cluster-autoscaler \
    --min-count 1 \
    --max-count 5 \
    --service-principal $AKS_SP_ID \
    --client-secret $AKS_SP_PASSWORD \
    --windows-admin-password $WIN_PASSWORD \
    --windows-admin-username $WIN_USER

    # If you have successfully created AAD integration with the admin consent, append these configs
    # --aad-server-app-id $SERVER_APP_ID \
    # --aad-server-app-secret $SERVER_APP_SECRET \
    # --aad-client-app-id $CLIENT_APP_ID \
    # --aad-tenant-id $TENANT_ID \

    # It is worth mentioning that soon the AKS cluster will no longer heavily depend on Service Principla to access
    # Azure APIs, rather it will be done again through Managed Identity which is way more secure
    # The following configuration can be used while provisioning the AKS cluster to enabled Managed Identity
    # --enable-managed-identity

# Connecting to AKS via kubectl
az aks get-credentials --resource-group $RG --name $CLUSTER_NAME --admin

# Test the connection
kubectl get nodes

# You will get something like this:
# NAME                                STATUS   ROLES   AGE     VERSION
# aks-npdefault-20070408-vmss000000   Ready    agent   5m3s    v1.15.3
# aks-npdefault-20070408-vmss000001   Ready    agent   5m10s   v1.15.3
# aks-npdefault-20070408-vmss000002   Ready    agent   5m2s    v1.15.3

### Activate Azure Monitor for containers live logs
# Docs: https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-live-logs
kubectl apply -f monitoring-log-reader-rbac.yaml

# AAD enable cluster needs different configuration. Refer to docs above to get the steps

### AKS Auto Scaler (No node pools used)
# To update autoscaler configuration on existing cluster 
# Refer to documentation: https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler
# Note this is (without node pools). Previous script uses node pools so it wont' work
# az aks update \
#   --resource-group $RG \
#   --name $CLUSTER_NAME \
#   --update-cluster-autoscaler \
#   --min-count 1 \
#   --max-count 10

# To disable autoscaler on the entire cluster run aks update
# Use --no-wait if you don't wait for the operation to finish (run in the background)
# This will not work with node pools enabled cluster. Use the node pool commands later for that.
# az aks update \
#   --resource-group $RG \
#   --name $CLUSTER_NAME \
#   --disable-cluster-autoscaler

# After autoscaler disabled, you can use az aks scale to control the cluster scaling
# Add --nodepool-name if you are managing multiple nodepools
# az aks scale --name $CLUSTER_NAME --node-count 3 --resource-group $RG

### AKS Node Pools
# Docs: https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools
# By default, an AKS cluster is created with a node pool that can run Linux containers. 
# Node Pools can have a different AKS version, that is why it can be used to safly upgrade/update part of the cluster
# Also it can have different VM sizes and different OS (like adding Windows pool)
# Use az aks nodepool add command to add an additional node pool that can run Windows Server containers.
WIN_NOODEPOOL=npwin
az aks nodepool add \
    --resource-group $RG \
    --cluster-name $CLUSTER_NAME \
    --os-type Windows \
    --name $WIN_NOODEPOOL \
    --node-count 1 \
    --max-pods 30 \
    --enable-cluster-autoscaler \
    --min-count 1 \
    --max-count 3 \
    --kubernetes-version $AKS_VERSION \
    --node-vm-size "Standard_DS2_v2" \
    --no-wait

# Listing all node pools
az aks nodepool list --resource-group $RG --cluster-name $CLUSTER_NAME -o table

# You can use also kubectl to see all the nodes (across both pools when the new one finishes)
kubectl get nodes

# To configure a specific node pool (like configuring autoscaler options) you can use:
NODEPOOL_NAME=$WIN_NOODEPOOL
az aks nodepool update \
    --resource-group $RG \
    --cluster-name $CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --update-cluster-autoscaler \
    --min-count 1 \
    --max-count 5

# Now to avoid Kubernetes from scheduling nodes incorrectly to node pools, you need to use taints and tolerations
# Example, when you have a Windows node pool, k8s can schedule linux pods their. What will happen then is the pod will
# never be able to start with error like "image operating system "linux" cannot be used on this platform"
# To avoid that, you can taint the Windows nodes with osType=win:NoSchedule
# Think of it like giving the windows node a bad smell (aka taint) so only pods with tolerance for can be schedule there.
kubectl taint node aksnpwin000000 osType=win:NoSchedule

# Delete a node pool
az aks nodepool delete \
    --resource-group $RG \
    --cluster-name $CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --no-wait

### AKS Upgrade
# Cluster Upgrade: https://docs.microsoft.com/en-us/azure/aks/upgrade-cluster
# Cluster with multiple node pools: https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools#upgrade-a-cluster-control-plane-with-multiple-node-pools
# Upgrading the cluster is a very critical process that you need to be prepared for
# AKS will support 2 minor versions previous to the current release

# First check for the upgrades
az aks get-upgrades \
    --resource-group $RG \
    --name $CLUSTER_NAME \
    | jq

# You can use az aks upgrade but will will upgrade the control plane and all node pools in the cluster.
# This is the only way to upgrade the control plane
az aks upgrade \
    --resource-group $RG \
    --name $CLUSTER_NAME \
    --kubernetes-version $AKS_VERSION
    --no-wait

# To upgrade a node pool
az aks nodepool upgrade \
    --resource-group $RG \
    --cluster-name $CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --kubernetes-version $AKS_VERSION \
    --no-wait

### AKS Node Restart After Upgrade
# As part of you upgrade strategy, node VMs OS sometime needs a restart (after a security patch install for example).
# Kured is an open source project that can support that process
# Docs: https://github.com/weaveworks/kured
# Kured (KUbernetes REboot Daemon) is a Kubernetes daemonset that performs safe automatic node reboots when the need 
# to do so is indicated by the package management system of the underlying OS.

# Deploying Kured to you cluster is a straight forward process (deployed to kured namespace):
kubectl apply -f https://github.com/weaveworks/kured/releases/download/1.2.0/kured-1.2.0-dockerhub.yaml

# If you wish to disable kured from restarting any nodes, you can run:
kubectl -n kube-system annotate ds kured weave.works/kured-node-lock='{"nodeID":"manual"}'

# Refer to the documenation on the link above to learn more

### Enable Virtual Nodes
# Docs: https://docs.microsoft.com/en-us/azure/aks/virtual-nodes-cli

# AKS can leverage Azure Container Instance (ACI) to expand the cluster capacity through on-demand provisioning
# of virtual nodes and pay per second for these expanded capacity
# Virtual Nodes are provisioned in the subnet to allow communication between Virutal Nodes and AKS nodes
# Check the above documentations for full details and the known limitations

# To use virutal nodes, you need AKS advanced networking enabled. Which we did
# Also we have setup a subnet to be used by virtual nodes and assigned access to AKS SP account.

# Make sure you have ACI provider registered
az provider list --query "[?contains(namespace,'Microsoft.ContainerInstance')]" -o table

# If not, you can register it now:
# az provider register --namespace Microsoft.ContainerInstance

# Now to activate it, you can execute the following command:
az aks enable-addons \
    --resource-group $RG \
    --name $CLUSTER_NAME \
    --addons virtual-node \
    --subnet-name $VNSUBNET_NAME

# Currently this will not work while cluster auto scaler is enabled on the (default node pool).
# You can disable it (if you got the error with this command)
NODEPOOL_NAME=$AKS_DEFAULT_NODEPOOL
az aks nodepool update \
    --resource-group $RG \
    --cluster-name $CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --disable-cluster-autoscaler

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
# kubernetes nodeSelector and tolerations in your deployment manifest like:
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
az aks disable-addons --resource-group $RG --name $CLUSTER_NAME --addons virtual-node

### Maintaining AKS Service Principal
# Docs: https://docs.microsoft.com/bs-latn-ba/azure/aks/update-credentials
# DON'T EXECUTE THESE SCRIPTS if you just provisioned your cluster. It is more about your long term strategy.
# From time to time (for example to be compliant with a security policy), you might need to update, reset or rotate
# AKS SP. Below are steps for reseting the password on existing cluster

# 1. Reseting the SP password

# Directly from AAD if you know the name
AKS_SP=$(az ad sp credential reset --name $AKS_SP_ID)

# OR from the AKS
AKS_SP_ID=$(az aks show --resource-group $RG --name $CLUSTER_NAME \
                --query servicePrincipalProfile.clientId -o tsv)
AKS_SP=$(az ad sp credential reset --name $AKS_SP_ID)

# Get the ID and Password
AKS_SP_ID=$(echo $AKS_SP | jq -r .appId)
AKS_SP_PASSWORD=$(echo $AKS_SP | jq -r .password)

echo $AKS_SP_ID
echo $AKS_SP_PASSWORD

# If you need to reset the SP for existing cluster use the following (takes a several moments of suspense =)
az aks update-credentials \
    --resource-group $RG \
    --name $CLUSTER_NAME \
    --reset-service-principal \
    --service-principal $AKS_SP_ID \
    --client-secret $AKS_SP_PASSWORD

# Troubleshooting note
# You got your cluster in (Failed State) don't panic
# You can check that the cluster APIs and worker nodes are still operational
# Just run az aks upgrade to resotre state
az aks upgrade --resource-group $RG --name $CLUSTER_NAME --kubernetes-version $VERSION

#***** END AKS Provisioning  *****

#***** AAD Role Binding Configuration *****

# NOTE: Execute the blow steps ONLY if you successfully completed the AAD provisioning 
# Grap the new cluster ADMIN credentials
# the AKS cluster with AAD enabled
# Objective here to grant your AAD account an admin access to the AKS cluster
az aks get-credentials --resource-group $RG --name $CLUSTER_NAME --admin

#List our currently available contexts
kubectl config get-contexts

#set our current context to the AKS admin context (by default not needed as get-credentials set the active context)
kubectl config use-context $CLUSTER_NAME-admin

#Check the cluster status through kubectl
kubectl get nodes

# Access Kubernetes Dashboard. You should have a lot of forbidden messages
# this would be due to that you are accessing the dashboard with a kubernetes-dashboard service account
# which by default don't have access to the cluster
az aks browse --resource-group $RG --name $CLUSTER_NAME

# Before you can use AAD account with AKS, a role or cluster role binding is needed.
# Let's grant the current logged user access to AKS via its User Principal Name (UPN)
# Get the UPN for a user in the same AAD direcotry
az ad signed-in-user show --query userPrincipalName -o tsv

# Use Object Id if the user is in external direcotry (like guest account on the directory)
az ad signed-in-user show --query objectId -o tsv

# Copy eaither the UPN or objectId to basic-azure-ad-binding.yaml file before applying the deployment
kubectl apply -f basic-azure-ad-binding.yaml

# We will try to get the credentials for the current logged user (without the --admin flag)
az aks get-credentials --resource-group $RG --name $CLUSTER_NAME

#List our currently available contexts. You should see a context without the -admin name
kubectl config get-contexts

#set our current context to the AKS admin context (by default not needed as get-credentials set the active context)
kubectl config use-context $CLUSTER_NAME

# try out the new context access :). You should notice the AAD login experience with a link and code to be entered in external browser. 
# You should be able to get the nodes after successful authentication
kubectl get nodes

# Great article about Kubernetes RBAC policies and setup https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/

#***** END AAD Role Binding Configuration *****

#***** Enable AAD Pod Identity *****
# Docs: https://github.com/Azure/aad-pod-identity

# Pod Identity can be used to allow AKS pods to access Azure resources (like App Gateway, storage,...) without using 
# explicity username and password. This would make access more secure. 
# This will be happing using normal kubernetes primitives and binding to pods happen seamlessly through
# selectors

# It is worth mentioning that Pod Identity is part of Azure AD Managed Identity platform which covers even more services
# that can leverage this secure way for authentication and authorization.
# Read more  here: https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview

# Run this command to create the aad-pod-identity deployment on our RBAC-enabled cluster:
# This will create the following k8s objects:
# First: NMI (Node Managed Idenityt) Deamon Set Deployment
# 1. Service Account for NMI
# 2. CRD for AzureAssignedIdentity, AzureIdentityBinding, AzureIdentity, AzureIdentityException
# 3. Cluster Role for NMI
# 4. Cluster Role binding for NMI Service Account
# 5. DeamonSet for NMI controller
# Second: MIC (Managed Identity Controller)
# 1. Service Account for MIC
# 2. Cluster Role for MIC
# 3. Cluster Role binding for MIC Service Account
# 4. Deployment of MIC
# Pods will be running in (default) namespace.

kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml

# You should see MIC/NMI pods running in each node
kubectl get pods -o wide

# MIC:
# The Managed Identity Controller (MIC) is a Kubernetes custom resource that watches for changes to pods, identities, 
# and bindings through the Kubernetes API server. 

# NMI:
# The Node Managed Identity deamonset identifies the pod based on the remote address of the request and then queries Kubernetes (through MIC) for 
# a matching Azure identity. NMI then makes an Azure Active Directory Authentication Library (ADAL) request to get the token for 
# the client id and returns it as a response. If the request had client id as part of the query, it is validated against the 
# admin-configured client id.

# To show case how pod identity can be used, we will create new MSI account, add it to the the cluster then
# assigned it to pods with a selector through a (aadpodidbinding) label matching it (which we will do later)
# We will be using "User-Assigned Managed Identity" which is a stand alound Managed Service Identity (MSI) that 
# can be reused accross multiple resources.
# Note we are graping the clientId, id and principalId
IDENTITY_NAME="${PREFIX}-pods-default-identity"
MANAGED_IDENTITY=$(az identity create -g $RG -n $IDENTITY_NAME)
# You can load the MSI of an existing one as well if you lost session or you have already one
# MANAGED_IDENTITY=$(az identity show -g $RG -n $IDENTITY_NAME)
echo $MANAGED_IDENTITY | jq
MANAGED_IDENTITY_CLIENTID=$(echo $MANAGED_IDENTITY | jq .clientId | tr -d '"')
echo $MANAGED_IDENTITY_CLIENTID
MANAGED_IDENTITY_ID=$(echo $MANAGED_IDENTITY | jq .id | tr -d '"')
echo $MANAGED_IDENTITY_ID
MANAGED_IDENTITY_SP_ID=$(echo $MANAGED_IDENTITY | jq .principalId | tr -d '"')
echo $MANAGED_IDENTITY_SP_ID

# Saving the MSI for later use
echo export MANAGED_IDENTITY_CLIENTID=$MANAGED_IDENTITY_CLIENTID >> ~/.bashrc
echo export MANAGED_IDENTITY_ID=$MANAGED_IDENTITY_ID >> ~/.bashrc
echo export MANAGED_IDENTITY_SP_ID=$MANAGED_IDENTITY_SP_ID >> ~/.bashrc

# Binding the new Azure Identity to AKS
# Replace the place holders with values we got the created managed identity
# I'm creating a new file so to maintain the generic nature of the file for repeated deployment
sed aad-pod-identity.yaml \
    -e s/NAME/$IDENTITY_NAME/g \
    -e 's@RESOURCE_ID@'"${MANAGED_IDENTITY_ID}"'@g' \
    -e s/CLIENT_ID/$MANAGED_IDENTITY_CLIENTID/g \
    > aad-pod-identity-updated.yaml

# Current deployment file uses type (0) which is for user assigned managed identity, which what we created. use (1) for SP
kubectl apply -f aad-pod-identity-updated.yaml

# Installing Azure Identity Binding
IDENTITY_BINDING_NAME="${PREFIX}-aad-identity-binding"
POD_SELECTOR="aad_enabled_pod"
sed aad-pod-identity-binding.yaml \
    -e s/NAME/$IDENTITY_NAME/g \
    -e 's@AAD_IDENTITY@'"${IDENTITY_NAME}"'@g' \
    -e s/AAD_SELECTOR/$POD_SELECTOR/g \
    > aad-pod-identity-binding-updated.yaml

kubectl apply -f aad-pod-identity-binding-updated.yaml

# The above binding will only applies with pods with label: aadpodidbinding=aad_enabled_pod
# NAME       READY     STATUS    RESTARTS   AGE       LABELS
# someapp   1/1       Running   10         10h       aadpodidbinding=aad_enabled_pod,app=someapp

# Now we set permission for Managed Identity Controller (MIC) for the user assigned identities 
# Because we deployed the Azure Identity outside the automatically created resource 
# group (has by default the name of MC_${RG}_${AKSNAME}_${LOC})
# we need to assign Managed Identity Operator role to the the AKS cluster service principal (so it can managed it)
AKS_SP_ID=$(az aks show \
    --resource-group $RG \
    --name $CLUSTER_NAME \
    --query servicePrincipalProfile.clientId -o tsv)
MIC_ASSIGNMENT=$(az role assignment create --role "Managed Identity Operator" --assignee $AKS_SP_ID --scope $MANAGED_IDENTITY_ID)
echo $MIC_ASSIGNMENT | jq

# Next steps is to have Azure roles/permissions assigned to the user assigned managed identity and map it to pods.
# For example, you can allow MSI to have reader access on the cluster resource group 
# (like /subscriptions/<subscriptionid>/resourcegroups/<resourcegroup>)
RG_ID=$(az group show --name $RG --query id -o tsv)
echo $RG_ID
az role assignment create --role Reader --assignee $MANAGED_IDENTITY_SP_ID --scope $RG_ID
# This to get the auto generated MC_ resource group for AKS cluster nodes
RG_NODE_NAME=$(az aks show \
    --resource-group $RG \
    --name $CLUSTER_NAME \
    --query nodeResourceGroup -o tsv)
RG_NODE_ID=$(az group show --name $RG_NODE_NAME --query id -o tsv)
echo $RG_NODE_ID
az role assignment create --role Reader --assignee $MANAGED_IDENTITY_SP_ID --scope $RG_NODE_ID

# By doing the same, you can assign different supported Azure resources to the MSI which then through MIC can be assigned to 
# pods via label selectors.
# Specifically, when a pod is scheduled, the MIC assigns an identity to the underlying VM during the creation phase. 
# When the pod is deleted, it removes the assigned identity from the VM. 
# The MIC takes similar actions when identities or bindings are created or deleted.
# Sample deployment will look like:
# apiVersion: extensions/v1beta1
# kind: Deployment
# metadata:
#   labels:
#     app: demo
#     aadpodidbinding: aad_enabled_pod
#   name: demo
#   namespace: dev
# spec:
#   **********

# One other key use is with App Gateway (incase if using it as ingress controller) by assinging MSI contributor role on the App Gateway

# Read more in the documenations: https://github.com/Azure/aad-pod-identity
# General documentation about Azure Managed Identities 
# https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview

#***** END Enable AAD Pod Identity *****

#***** AAD and AKS RBAC Access Control Configuration *****

# Documentation https://docs.microsoft.com/en-us/azure/aks/azure-ad-rbac
# NOTE: You can leverage the below steps only if you successfully provided AAD enabled AKS cluster

# We will be creating 2 roles: (appdev) group with a user called aksdev1, 
# (opssre) with user akssre1 (SRE: Site Reliablity Engineer)
# Note: In production environments, you can use existing users and groups within an Azure AD tenant.

# We will need the AKS resource id during the provisioning
AKS_ID=$(az aks show \
    --resource-group $RG \
    --name $CLUSTER_NAME \
    --query id -o tsv)

# Create the "appdev" group. Sometime you need to wait for a few seconds for the new group to be fully availabe for the next steps
APPDEV_ID=$(az ad group create \
    --display-name appdev \
    --mail-nickname appdev \
    --query objectId -o tsv)

# Create Azure role assignemnt for appdev group, this will allow members to access AKS via kubectl
az role assignment create \
  --assignee $APPDEV_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $AKS_ID

# Now creating the opssre group
OPSSRE_ID=$(az ad group create \
    --display-name opssre \
    --mail-nickname opssre \
    --query objectId -o tsv)

# Assigning the gourp to role on the AKS cluster
az role assignment create \
  --assignee $OPSSRE_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $AKS_ID

# Creating our developer user account
AKSDEV1_ID=$(az ad user create \
  --display-name "AKS Dev 1" \
  --user-principal-name aksdev1@mobivisions.com \
  --password P@ssw0rd1 \
  --query objectId -o tsv)

# Adding the new user to the appdev group
az ad group member add --group appdev --member-id $AKSDEV1_ID

# Create a user for the SRE role
AKSSRE1_ID=$(az ad user create \
  --display-name "AKS SRE 1" \
  --user-principal-name akssre1@mobivisions.com \
  --password P@ssw0rd1 \
  --query objectId -o tsv)

# Add the user to the opssre Azure AD group
az ad group member add --group opssre --member-id $AKSSRE1_ID

# Create AKS cluster resources for appdev group
# Make sure that you on the cluster admin context to execute the following commands. You can make sure that active context has -admin in it.
kubectl config use-context $CLUSTER_NAME-admin

# We will be using namespace isolation. We will create a dev namespace for the developers to use
kubectl create namespace dev

# In Kubernetes, Roles define the permissions to grant, and RoleBindings apply them to desired users or groups. 
# These assignments can be applied to a given namespace, or across the entire cluster.
# So first we will create a Role with full access to dev namespace through applying the manifest role-dev-namespace.yaml
kubectl apply -f role-dev-namespace.yaml

# We need the group resource ID for appdev group to be replaced in the role binding deployment file
az ad group show --group appdev --query objectId -o tsv

# Replace the group id in rolebinding-dev-namespace.yaml before applying the deployment
sed -i rolebinding-dev-namespace.yaml -e "s/groupObjectId/$APPDEV_ID/g"
kubectl apply -f rolebinding-dev-namespace.yaml

# Doing the same to create access for the SRE
kubectl create namespace sre

kubectl apply -f role-sre-namespace.yaml

az ad group show --group opssre --query objectId -o tsv

# Update the opssre group id to rolebinding-sre-namespace.yaml before applying the deployment
sed -i rolebinding-sre-namespace.yaml -e "s/groupObjectId/$OPSSRE_ID/g"
kubectl apply -f rolebinding-sre-namespace.yaml

# Testing now can be done by switching outside of the context of the admin to one of the users created

# Reset the creditnails for AKS so you will sign in with the dev user
az aks get-credentials --resource-group $RG --name $CLUSTER_NAME --overwrite-existing

# Now lets try to get nodes. You should have the AAD sign in experience. After signing in with Dev user, you should see it is forbidden :)
kubectl get nodes

# Lets try run a bsic NGINX pod on the dev namespace (in case you signed in with a dev user)
kubectl run --generator=run-pod/v1 nginx-dev --image=nginx --namespace dev

# The above command should say: pod/nginx-dev created. Let's see if it is running
kubectl get pods --namespace dev

# Another test is to try to get pods from all namespaces (you should get forbidden again :)
kubectl get pods --all-namespaces
# Error from server (Forbidden): pods is forbidden: User "YOURDEVUSER@TENANT.COM" cannot list resource "pods" in 
# API group "" at the cluster scope

# One final test to schedule a pod in a different namespace (sre for example)
kubectl run --generator=run-pod/v1 nginx-dev --image=nginx --namespace sre
# Error from server (Forbidden): pods is forbidden: User "YOURDEVUSER@TENANT.COM" cannot create resource "pods" in 
# API group "" in the namespace "sre"

# More information about authentication and authirization here https://docs.microsoft.com/en-us/azure/aks/operator-best-practices-identity

# Let's clean up after ourselves

# Get the admin kubeconfig context to delete the necessary cluster resources
kubectl config use-context $CLUSTER_NAME-admin
# Or use this if you don't have the admin context from the previous steps
az aks get-credentials --resource-group $RG --name $CLUSTER_NAME --admin

# You can delete only the pods and let the users, groups, namespaces intact or delete everything
kubectl delete pod nginx-dev --namespace dev

# Delete the dev and sre namespaces. This also deletes the pods, Roles, and RoleBindings
kubectl delete namespace dev
kubectl delete namespace sre

# Delete the Azure AD user accounts for aksdev and akssre
az ad user delete --upn-or-object-id $AKSDEV1_ID
az ad user delete --upn-or-object-id $AKSSRE1_ID

# Delete the Azure AD groups for appdev and opssre. This also deletes the Azure role assignments.
az ad group delete --group appdev
az ad group delete --group opssre

#***** END AAD and AKS RBAC Access Control Configuration *****

#***** Configure AKS Dashboard Access with AAD *****

# NOTE: You can leverage the below steps only if you successfully provided AAD enabled AKS cluster

# Create the "aks-dashboard-admins" group. Sometime you need to wait for a few seconds for the new group to be fully availabe for the next steps
DASHBOARD_ADMINS_ID=$(az ad group create \
    --display-name AKS-Dashboard-Admins \
    --mail-nickname aks-dashboard-admins \
    --query objectId -o tsv)

# Create Azure role assignemnt for the group, this will allow members to access AKS via kubectl, dashboard
az role assignment create \
  --assignee $DASHBOARD_ADMINS_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $AKS_ID

# We will add the current logged in user to the dashboard admins group
# Get the UPN for a user in the same AAD direcotry
SIGNED_USER_UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv)

# Use Object Id if the user is in external direcotry (like guest account on the directory)
SIGNED_USER_UPN=$(az ad signed-in-user show --query objectId -o tsv)

# Add the user to dashboard group
az ad group member add --group $DASHBOARD_ADMINS_ID --member-id $SIGNED_USER_UPN

# Create role and role binding for the new group (after replacing the AADGroupID)
sed -i dashboard-proxy-binding.yaml -e "s/AADGroupID/$DASHBOARD_ADMINS_ID/g"
kubectl apply -f dashboard-proxy-binding.yaml

# As a workaround accessing the dashboard using a token without enforcing https secure communication (tunnel is exposed ver http), 
# you can edit the dashboard deployment with adding the following argument
# It is an issue currently being discussed here https://github.com/MicrosoftDocs/azure-docs/issues/23789
# args: ["--authentication-mode=token", "--enable-insecure-login"] under spec: containers
# spec:
#   containers:
#   - name: *****
#     image: *****
#     args: ["--authentication-mode=token", "--enable-insecure-login"]
kubectl edit deploy -n kube-system kubernetes-dashboard

# Get AAD token for the signed in user (given that user has the approperiate access). Use (az login) if you are not signed in
SIGNED_USER_TOKEN=$(az account get-access-token --query accessToken -o tsv)
echo $SIGNED_USER_TOKEN

# establish a tunnel and login via token above
# If AAD enabled, you should see the AAD sign in experience with a link and a code to https://microsoft.com/devicelogin
az aks browse --resource-group $RG --name $CLUSTER_NAME

# You can also use kubectl proxy to establish the tunnel as well
# kubectl proxy
# Then you can navigate to sign in is located http://localhost:8001/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy/#!/login

# Note: you can also use the same process but with generated kubeconfig file for a Service Account that is bound to a specific namespace 
# to login to the dashboad.

#***** END Configure AKS Dashboard Access with AAD *****

#***** Setting up Azure Container Registry *****

# Create Azure Container Registry
az acr create --resource-group $RG --name $CONTAINER_REGISTRY_NAME --sku Basic

# Get the Service Princaple ID for the AKS Cluster
AKS_SP_ID=$(az aks show --resource-group $RG --name $CLUSTER_NAME --query servicePrincipalProfile.clientId --output tsv)
echo $AKS_SP_ID

# Get the Resource ID for the ACR
ACR_ID=$(az acr show --name $CONTAINER_REGISTRY_NAME --resource-group $RG --query id --output tsv)
echo $ACR_ID

# Create the role assignment to allow AKS authenticating agains the ACR
az role assignment create --assignee $AKS_SP_ID --role AcrPull --scope $ACR_ID

# Check the list of permissions here: https://docs.microsoft.com/en-us/azure/container-registry/container-registry-roles

#***** END Setting up Container Register *****

#***** Helm Configuration ******
# Assuming that helm client is installed. If not you can follow online instruction to install it.
# If you need information about installing helm check this https://docs.helm.sh/using_helm/#installing-helm
# I'm currently using v2.14.3
helm version

# If you want to upgrade helm, I used brew on WSL
# brew upgrade kubernetes-helm

# Installing Tiller (helm server side client) on the AKS cluster
# First, check the role and service account that will be used by tiller
# The below deployment assign tiller a cluster-admin role
# Note: I would not recommend using this a cluster-admin binded tiller unless there is a specific need
# We will use the cluster-tiller to deploy App Gateway Ingress Controller and other cluster wide services
cat helm-admin-rbac.yaml

# If you need further control over tiller access (higly recommended), the custom rbac creates custom role 
# and bind it to tiller service account
more helm-dev-rbac.yaml
more helm-sre-rbac.yaml

# As Helm will use the current configured context for kubectl, let's make sure the right context is set (admin)
kubectl config get-contexts

# Cluster-Tiller SA: 
# Now we can use that SA to initialize tiller with that service account using helm client
# Creating a SA (Service Account) to be used by tiller in RBAC enabled clusters with cluster-admin role
# Using TLS is higly recommended through --tiller-tls-verify. You can refer back to helm documentation for how to generate 
# the required certificates
kubectl apply -f helm-admin-rbac.yaml
helm init --service-account tiller-admin
helm init --upgrade

# Validate tiller was initialized successfully
helm version

# Check if tiller pod initialized and ready
kubectl get pods -n kube-system

# Dev-Tiller
# Creating a SA (Service Account) to be used by tiller in RBAC enabled clusters with custom role
# Sometime deployments will require to provision roles using API Group "rback.authorization.k8s.io" scoped to the namespace. 
# That is why we used (apiGroups: ["*"]} in the rbac definition.
# If you limit the API access to tiller you might get error like: cannot create resource "roles" in API group 
# "rbac.authorization.k8s.io" in the namespace "dev"

# Create the dev namespace if you didn't do already in previous steps
kubectl create namespace dev

kubectl apply -f helm-dev-rbac.yaml
helm init --service-account tiller-dev --tiller-namespace dev

# Check if tiller is running in the dev namespace
kubectl get po --namespace dev

# SRE-Tiller
# Creating a SA (Service Account) to be used by tiller in RBAC enabled clusters with custom role
# Create the sre namespace if you didn't do already in previous steps
kubectl create namespace sre

kubectl apply -f helm-sre-rbac.yaml
helm init --service-account tiller-sre --tiller-namespace sre

# Check if tiller is running in the sre namespace
kubectl get po --namespace sre

#Notice the tiller-deploy when you retrieve deployments in our 3 namespaces (kube-system, dev and sre)
kubectl get deployments --all-namespaces

### KUBECONFIG file for CI/CD
# Getting a kubeconfig file to be used for tiller deployments in CI/CD pipeline
# Make sure you are running under admin and with the right context activated
TILLER_NAMESPACE="dev"
TILLER_SERVICE_ACCOUNT="tiller-${TILLER_NAMESPACE}"
EXPORT_FOLDER="/tmp/kubeconf-${TILLER_NAMESPACE}"
KUBE_CONF_FILE_NAME="${EXPORT_FOLDER}/k8s-${TILLER_SERVICE_ACCOUNT}-conf"
mkdir -p "${EXPORT_FOLDER}"

# Below commands leverage jq for json parsing. Read more here https://stedolan.github.io/jq/
# Installing jq can be done via several methods, I used (brew install jq)

TILLER_SECRET_NAME=$(kubectl get sa "${TILLER_SERVICE_ACCOUNT}" --namespace $TILLER_NAMESPACE -o json | jq -r .secrets[].name)
echo $TILLER_SECRET_NAME

# Token must be decoded from base64 encoding so it can be sotred in the config file. 
# base64 encode and decode documentation here https://linuxhint.com/bash_base64_encode_decode/
TILLER_SECRET_TOKEN=$(kubectl get secret "${TILLER_SECRET_NAME}" --namespace $TILLER_NAMESPACE -o json | jq -r '.data["token"]' | base64 -d)
echo $TILLER_SECRET_TOKEN

# Get active cluster name if you want to automate naming convention
ACTIVE_CLUSTER_NAME=$(kubectl config get-contexts "$(kubectl config current-context)" | awk '{print $3}' | tail -n 1)
echo $ACTIVE_CLUSTER_NAME

# Export the access certificate to target folder
kubectl get secret "${TILLER_SECRET_NAME}" \
    --namespace $TILLER_NAMESPACE -o json \
    | jq \
    -r '.data["ca.crt"]' | base64 -d > "${EXPORT_FOLDER}/ca.crt"

# We will need the endpoint when we consruct our new configuration file
K8S_CLUSTER_ENDPOINT=$(kubectl config view \
    -o jsonpath="{.clusters[?(@.name == \"${CLUSTER_NAME}\")].cluster.server}")
echo $K8S_CLUSTER_ENDPOINT

# Setup the config file
kubectl config set-cluster "${ACTIVE_CLUSTER_NAME}" \
    --kubeconfig="${KUBE_CONF_FILE_NAME}" \
    --server="${K8S_CLUSTER_ENDPOINT}" \
    --certificate-authority="${EXPORT_FOLDER}/ca.crt" \
    --embed-certs=true

# Setting token credentials entry in kubeconfig
kubectl config set-credentials \
    "${TILLER_SERVICE_ACCOUNT}" \
    --kubeconfig="${KUBE_CONF_FILE_NAME}" \
    --token="${TILLER_SECRET_TOKEN}"

# Setting a context entry in kubeconfig
kubectl config set-context \
    "${TILLER_SERVICE_ACCOUNT}" \
    --kubeconfig="${KUBE_CONF_FILE_NAME}" \
    --cluster="${ACTIVE_CLUSTER_NAME}" \
    --user="${TILLER_SERVICE_ACCOUNT}" \
    --namespace="${TILLER_NAMESPACE}"

# Let's test. First unauthorized access to all namespaces
KUBECONFIG=${KUBE_CONF_FILE_NAME} kubectl get po --all-namespaces

# KUBECONFIG=${KUBE_CONF_FILE_NAME} kubectl describe po tiller-deploy-7c694947b9-dr6sf
# Successful access :)
KUBECONFIG=${KUBE_CONF_FILE_NAME} kubectl get po --namespace dev

# Basic deployment using helm
helm init --service-account tiller-dev --tiller-namespace dev --kubeconfig=$KUBE_CONF_FILE_NAME

# First forbidden deployment to sre namespace
helm install stable/nginx-ingress \
    --name sre-nginx-ingress \
    --namespace sre \
    --tiller-namespace sre \
    --kubeconfig=$KUBE_CONF_FILE_NAME

# Second, successful deployment to dev namespace
helm install stable/nginx-ingress \
    --set controller.scope.enabled=true \
    --set controller.scope.namespace=dev \
    --name dev-nginx-ingress \
    --namespace dev --tiller-namespace dev \
    --kubeconfig=$KUBE_CONF_FILE_NAME

# Checking the deployment status (you should see a successful deployment)
helm ls --all dev-nginx-ingress --tiller-namespace dev --kubeconfig=$KUBE_CONF_FILE_NAME

# 2 new pods should be running with dev-nginx-ingress prefix :)
KUBECONFIG=${KUBE_CONF_FILE_NAME} kubectl get po --namespace dev

# Deleting the deployment package with its associated nginx pods
helm del --purge dev-nginx-ingress \
    --tiller-namespace dev \
    --kubeconfig=$KUBE_CONF_FILE_NAME #WARNING! Premenant deletion

# To view the created conf file, navigate to the export folder and read the conf file
cd "${EXPORT_FOLDER}" #OPTIONAL. You will find the ca.crt and config file
ls -l
# You should see something like:
# -rw-rw-rw- 1 localadmin localadmin 1716 Oct  2 10:01 ca.crt
# -rw------- 1 localadmin localadmin 6317 Oct  2 10:03 k8s-tiller-dev-conf

# The config file then can be securely copied to CI/CD pipeline
# Incase of Azure DevOps, you can create a new Kubernetes Service connection under the project settings using this kubeconfig file. 
# Don't worry if you get forbbiden error as the test tries to get all namespaces pods :)
more "${KUBE_CONF_FILE_NAME}"

### Merging the new tiller-dev KUBECONFIG with the root KUBECONFIG
# List all available context to kubectl (active one will have *)
kubectl config get-contexts

# NOTE: Don't attempt the below steps if you config you are merging already exists in the root config
# To be save, let's copy a backup from the root config
cp $HOME/.kube/config $HOME/.kube/config.backup.$(date +%Y-%m-%d.%H:%M:%S)

# Piping original with the new context files and overwrite the original config
KUBECONFIG=$HOME/.kube/config:$KUBE_CONF_FILE_NAME: kubectl config view --merge --flatten \
    > \
    ~/.kube/merged_kubeconfig && mv ~/.kube/merged_kubeconfig ~/.kube/config

# List all available context to kubectl (active one will have *)
kubectl config get-contexts

# You should see something similar to this
# CURRENT   NAME                           CLUSTER                  AUTHINFO                                         NAMESPACE
# *         CLUSTER-NAME-admin             CLUSTER-NAME             clusterAdmin_RESOURCEGROUP_CLUSTER-NAME         
#           tiller-dev                     CLUSTER-NAME             tiller-dev                                       dev

# To switch to tiller-dev context:
kubectl config use-context tiller-dev

# Try something forbidden :)
kubectl get pods --all-namespaces

# I will let you switch back to admin context so you can proceed with the below steps

#***** END Helm Configuration ******

#***** App Gateway Ingress Controller Provisioing *****

# Docs: https://github.com/Azure/application-gateway-kubernetes-ingress 
# Greenfield Deployment: https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/setup/install-new.md
# Brownfield Deployment: https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/setup/install-existing.md
# You can provision the AGIC either through using AAD Pod Identity or SP. As best practice, I'm using Pod Identity.

AGW_IDENTITY_NAME="${PREFIX}-agw-identity"
AGW_NAME="${PREFIX}-agw"
AGW_PUBLICIP_NAME="${PREFIX}-agw-pip"

# Create pulbic IP for the gateway. 
# Using standard sku allow extra security as it is closed by default and allow traffic through NSGs
# More infor here: https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-ip-addresses-overview-arm
az network public-ip create -g $RG -n $AGW_PUBLICIP_NAME -l $LOCATION --sku Standard

# Provision the app gateway
# Note to maintain SLA, you need to set --min-capacity to at least 2 instances
# Azure Application Gateway must be v2 skus
# App Gateway will be used as ingress controller: https://azure.github.io/application-gateway-kubernetes-ingress/
# In earlier step we provisioned a vNet with a subnet dedicated for App Gateway.

az network application-gateway create \
  --name $AGW_NAME \
  --resource-group $RG \
  --location $LOCATION \
  --min-capacity 2 \
  --frontend-port 80 \
  --http-settings-cookie-based-affinity Disabled \
  --http-settings-port 80 \
  --http-settings-protocol Http \
  --routing-rule-type Basic \
  --sku WAF_v2 \
  --private-ip-address 10.42.3.12 \
  --public-ip-address $AGW_PUBLICIP_NAME \
  --subnet $AGW_SUBNET_NAME \
  --vnet-name $VNET_NAME

# We need the resource id in order to assign role to AGW managed identity
AGW_RESOURCE_ID=$(az network application-gateway show --name $AGW_NAME --resource-group $RG --query id --output tsv)
echo $AGW_RESOURCE_ID

# Installing App Gateway Ingress Controller
# Setup Documentation on existing cluster: https://azure.github.io/application-gateway-kubernetes-ingress/setup/install-existing/
# Setup Documentation on new cluster: https://azure.github.io/application-gateway-kubernetes-ingress/setup/install-new/

# Make sure helm is installed (for kube-system). Steps for helm preprartion mentioned above
helm init --tiller-namespace kube-system --service-account tiller-admin

# Adding AGIC helm repo
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

# Get AKS server URL
AKS_FQDN=$(az aks show -n $CLUSTER_NAME -g $RG --query 'fqdn' -o tsv)
echo $AKS_FQDN

# AGIC needs to authenticate to ARM to be able to managed the App Gatway and ready AKS resources
# You have 2 options to do that

### OPTION 1: Using (Pod Identity)
# Assuming you got your Pod Identity setup completed successfully in the previous steps, let's provision the AGIC

# Creating User Managed Identity to be used to by AGIC to access AGW (integration is done through Pod Identity)
# Create new AD identity
AGW_MANAGED_IDENTITY=$(az identity create -g $RG -n $AGW_IDENTITY_NAME)
# You can load the MSI of an existing one as well if you lost session or you have already one
# AGW_MANAGED_IDENTITY=$(az identity show -g $RG -n $AGW_IDENTITY_NAME)
echo $AGW_MANAGED_IDENTITY | jq
#AGW_MANAGED_IDENTITY_CLIENTID=$(echo $AGW_MANAGED_IDENTITY | jq .clientId | tr -d '"')
AGW_MANAGED_IDENTITY_CLIENTID=$(echo $AGW_MANAGED_IDENTITY | jq -r .clientId)
echo $AGW_MANAGED_IDENTITY_CLIENTID
AGW_MANAGED_IDENTITY_ID=$(echo $AGW_MANAGED_IDENTITY | jq .id | tr -d '"')
echo $AGW_MANAGED_IDENTITY_ID
# We need the principalId for role assignment
AGW_MANAGED_IDENTITY_SP_ID=$(echo $AGW_MANAGED_IDENTITY | jq .principalId | tr -d '"')
echo $AGW_MANAGED_IDENTITY_SP_ID

# User Identity needs Reader access to AKS Resource Group and Nodes Resource Group, let's get its id
RG_ID=$(az group show --name $RG --query id -o tsv)
RG_NODE_NAME=$(az aks show \
    --resource-group $RG \
    --name $CLUSTER_NAME \
    --query nodeResourceGroup -o tsv)
RG_NODE_ID=$(az group show --name $RG_NODE_NAME --query id -o tsv)

echo $RG_ID
echo $RG_NODE_ID

# Create the assignment (note that you might need to wait if you got "no matches in graph database")
az role assignment create --role Reader --assignee $AGW_MANAGED_IDENTITY_CLIENTID --scope $RG_NODE_ID
az role assignment create --role Reader --assignee $AGW_MANAGED_IDENTITY_CLIENTID --scope $RG_ID
az role assignment create --role Contributor --assignee $AGW_MANAGED_IDENTITY_CLIENTID --scope $AGW_RESOURCE_ID
az role assignment create --role "Managed Identity Operator" --assignee $AKS_SP_ID --scope $AGW_MANAGED_IDENTITY_ID

# Note: I would recommend taking a short break now before proceeding the the above assignments is for sure done.

# To get the latest helm-config.yaml for AGIC run this (notice you active folder)
# wget https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/sample-helm-config.yaml -O helm-config.yaml

# have a look at the deployment:
cat agic-helm-config.yaml

# Lets replace some values and output a new updated config
sed agic-helm-config.yaml \
    -e 's@<subscriptionId>@'"${SUBSCRIPTION_ID}"'@g' \
    -e 's@<resourceGroupName>@'"${RG}"'@g' \
    -e 's@<applicationGatewayName>@'"${AGW_NAME}"'@g' \
    -e 's@<identityResourceId>@'"${AGW_MANAGED_IDENTITY_ID}"'@g' \
    -e 's@<identityClientId>@'"${AGW_MANAGED_IDENTITY_CLIENTID}"'@g' \
    -e "s/\(^.*enabled: \).*/\1true/gI" \
    -e 's@<aks-api-server-address>@'"${AKS_FQDN}"'@g' \
    > agic-helm-config-updated.yaml

# have a final look on the yaml before deploying :)
cat agic-helm-config-updated.yaml

# Note that this deployment doesn't specify a kubernetes namespace, which mean AGIC will monitor all namespaces

# Execute the installation
helm install --name $AGW_NAME \
    -f agic-helm-config-updated.yaml application-gateway-kubernetes-ingress/ingress-azure \
    --namespace default

# tiller will deploy the following:
# RESOURCES:
# ==> v1/AzureIdentity
# NAME                           AGE
# aksdev-agw-azid-ingress-azure  1s

# ==> v1/AzureIdentityBinding
# NAME                                  AGE
# aksdev-agw-azidbinding-ingress-azure  1s

# ==> v1/ConfigMap
# NAME                         DATA  AGE
# aksdev-agw-cm-ingress-azure  6     1s

# ==> v1/Pod(related)
# NAME                                       READY  STATUS             RESTARTS  AGE
# aksdev-agw-ingress-azure-67cb6686fb-fqt4z  0/1    ContainerCreating  0         1s

# ==> v1/ServiceAccount
# NAME                         SECRETS  AGE
# aksdev-agw-sa-ingress-azure  1        1s

# ==> v1beta1/ClusterRole
# NAME                      AGE
# aksdev-agw-ingress-azure  1s

# ==> v1beta1/ClusterRoleBinding
# NAME                      AGE
# aksdev-agw-ingress-azure  1s

# ==> v1beta2/Deployment
# NAME                      READY  UP-TO-DATE  AVAILABLE  AGE
# aksdev-agw-ingress-azure  0/1    1           0          1s

### OPTION 2: Using (Service Principal)

# Create a new SP to be used by AGIC through Kubernetes secrets
AGIC_SP_NAME="${PREFIX}-agic-sp"
AGIC_SP_AUTH=$(az ad sp create-for-rbac --skip-assignment --name $AGIC_SP_NAME --sdk-auth | base64 -w0)
AGIC_SP=$(az ad sp show --id http://$AGIC_SP_NAME)
echo $AGIC_SP | jq
AGIC_SP_ID=$(echo $AGIC_SP | jq -r .appId)
echo $AGIC_SP_ID

az role assignment create --role Reader --assignee $AGIC_SP_ID --scope $RG_NODE_ID
az role assignment create --role Reader --assignee $AGIC_SP_ID --scope $RG_ID
az role assignment create --role Contributor --assignee $AGIC_SP_ID --scope $AGW_RESOURCE_ID

sed agic-sp-helm-config.yaml \
    -e 's@<subscriptionId>@'"${SUBSCRIPTION_ID}"'@g' \
    -e 's@<resourceGroupName>@'"${RG}"'@g' \
    -e 's@<applicationGatewayName>@'"${AGW_NAME}"'@g' \
    -e 's@<secretJSON>@'"${AGIC_SP_AUTH}"'@g' \
    -e "s/\(^.*enabled: \).*/\1true/gI" \
    -e 's@<aks-api-server-address>@'"${AKS_FQDN}"'@g' \
    > agic-sp-helm-config-updated.yaml

# have a final look on the yaml before deploying :)
cat agic-sp-helm-config-updated.yaml

# Note that this deployment doesn't specify a kubernetes namespace, which mean AGIC will monitor all namespaces

# Execute the installation
helm install --name $AGW_NAME \
    -f agic-sp-helm-config-updated.yaml application-gateway-kubernetes-ingress/ingress-azure\
    --namespace default

# Just check of the pods are up and running :)
kubectl get pods

### Testing with simple nginx deployment (pod, service and ingress)
# The following manifest will create:
# 1. A deployment named nginx (basic nginx deployment)
# 2. Service exposting the nginx deployment via internal loadbalancer. Service is deployed in the services subnet created earlier
# 3. Ingress to expose the service via App Gateway public IP (using AGIC)

# Before applying the file, we just need to update it with our services subnet we created earlier :)
sed nginx-deployment.yaml \
    -e s/SVCSUBNET/$SVCSUBNET_NAME/g \
    > nginx-deployment-updated.yaml

# Have a look at the test deployment:
cat nginx-deployment-updated.yaml

# Let's apply
kubectl apply -f nginx-deployment-updated.yaml

# Here you need to wait a bit to make sure that the service External (local) IP is assigned before applying the ingress controller
kubectl get service nginx-service
# NAME            TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
# nginx-service   LoadBalancer   10.41.139.83   10.42.2.4     80:31479/TCP   18m

# If you need to check the deploymont, pods or services provisioned, use these popular kubectl commands:
kubectl get pods
kubectl get service nginx-service
kubectl describe svc nginx-service

# Now everything is good, let's apply the ingress
kubectl apply -f nginx-ingress-deployment.yaml

# Perform checks internally:
kubectl get ingress 
# NAME         HOSTS   ADDRESS          PORTS   AGE
# nginx-agic   *       40.119.158.142   80      8m24s
kubectl describe ingress nginx-agic

# Test if the service is actually online via the App Gateway Public IP
AGW_PUBLICIP_ADDRESS=$(az network public-ip show -g $RG -n $AGW_PUBLICIP_NAME --query ipAddress -o tsv)
curl http://$AGW_PUBLICIP_ADDRESS
# You should see default nginx welcome html

### Exposing HTTPS via AGIC
# The first challenge is we need a certificate (for encrypting the communications)
# Certificates comes in pairs (key and cert files). You can check https://letsencrypt.org/ for maybe a freebie :)
# I will assume you have them
# Certificate will be deploy through Kubernetes secrets
CERT_SECRET_NAME=agic-nginx-cert
CERT_KEY_FILE="REPLACE"
CERT_FILE="REPLACE"
kubectl create secret tls $CERT_SECRET_NAME --key $CERT_KEY_FILE --cert $CERT_FILE

# Update secret name in the deployment file
sed nginx-ingress-tls-deployment.yaml \
    -e s/SECRET_NAME/$CERT_SECRET_NAME/g \
    > nginx-ingress-tls-deployment-updated.yaml

kubectl apply -f nginx-ingress-tls-deployment-updated.yaml

# Check again for the deployment status.
# If successful, the service will be avaialbe via both HTTP and HTTPS

# You ask, what about host names (like mydomain.coolcompany.com)
# Answer is simple, just update the tls yaml section related to tls:
# tls:
#   - hosts:
#     - <mydomain.coolcompany.com>
#     secretName: <guestbook-secret-name>

# After applying the above, you will not be able to use the IP like before, you need to add 
# record (like A record) from your domain DNS manager or use a browser add-on tool that allows 
# you to embed the host in the request

# Demo cleanup :)
kubectl delete deployment nginx-deployment
kubectl delete service nginx-service
kubectl delete ingress nginx-agic

### Removing AGIC
# Helm make it easy to delete the AGIC deployment to start over
# helm del --purge $AGW_NAME

#***** END App Gateway Provisioing *****

#***** Clean Up Resources *****

# As Service Principal created on the AAD directory, it will not be deleted automatically with the resource group
# Use this command if you wish to delete it
az ad sp delete --id $(az aks show -g $RG -n $CLUSTER_NAME --query servicePrincipalProfile.clientId -o tsv)
# Or 
az ad sp delete --id "http://${PREFIX}-aks-sp"

# This command will delete all resources provisioned except AAD provisions for accounts, groups and/or service principals
az group delete --name $RG --yes --no-wait

# You can also use specific resources deletes if you wish too

#***** END Clean Up Resources *****

#***** Useful Tips *****

# Get AKS resources yaml
kubectl get deployment,service,pod yourapp -o yaml --export

# In addition to Azure Monitor for containers, you can deploy app insights to your application code
# App Insights support many platforms like .NET, Java, and NodeJS.
# Docs: https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview
# Check Kubernetes apps with no instrumentation and service mesh: https://docs.microsoft.com/en-us/azure/azure-monitor/app/kubernetes
# Create App Insights to be used whithin your apps:
APP_NAME="${PREFIX}-myapp-insights"
APPINSIGHTS_KEY=$(az resource create \
    --resource-group ${RG} \
    --resource-type "Microsoft.Insights/components" \
    --name ${APP_NAME} \
    --location ${LOCATION} \
    --properties '{"Application_Type":"web"}' \
    | grep -Po "\"InstrumentationKey\": \K\".*\"")
echo $APPINSIGHTS_KEY