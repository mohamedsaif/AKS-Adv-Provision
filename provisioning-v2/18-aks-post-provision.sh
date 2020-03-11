#!/bin/bash

# Make sure that variables are updated
source ./aks.vars

# This script go through the following:
# - Connecting to AKS
# - Live monitoring entablement
# - AKS autoscaler
# - AKS Virtual Nodes
# - Helm 2 Setup

# Connecting to AKS via kubectl
# append --admin on the below command if you enabled AAD as your account by default you don't have access
az aks get-credentials --resource-group $RG_AKS --name $AKS_CLUSTER_NAME

# Test the connection
kubectl get nodes

# You will get something like this:
# NAME                                STATUS   ROLES   AGE     VERSION
# aks-npdefault-20070408-vmss000000   Ready    agent   5m3s    v1.15.3
# aks-npdefault-20070408-vmss000001   Ready    agent   5m10s   v1.15.3
# aks-npdefault-20070408-vmss000002   Ready    agent   5m2s    v1.15.3

### Activate Azure Monitor for containers live logs
# Docs: https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-live-logs
kubectl apply -f ./deployments/monitoring-log-reader-rbac.yaml

# AAD enable cluster needs different configuration. Refer to docs above to get the steps

### AKS Auto Scaler (No node pools used)
# To update autoscaler configuration on existing cluster 
# Refer to documentation: https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler
# Note this is (without node pools). Previous script uses node pools so it wont' work
# az aks update \
#   --resource-group $RG_AKS \
#   --name $AKS_CLUSTER_NAME \
#   --update-cluster-autoscaler \
#   --min-count 1 \
#   --max-count 10

# To disable autoscaler on the entire cluster run aks update
# Use --no-wait if you don't wait for the operation to finish (run in the background)
# This will not work with node pools enabled cluster. Use the node pool commands later for that.
# az aks update \
#   --resource-group $RG_AKS \
#   --name $AKS_CLUSTER_NAME \
#   --disable-cluster-autoscaler

# After autoscaler disabled, you can use az aks scale to control the cluster scaling
# Add --nodepool-name if you are managing multiple node pools
# az aks scale --name $AKS_CLUSTER_NAME --node-count 3 --resource-group $RG

### Enable Virtual Nodes
# Docs: https://docs.microsoft.com/en-us/azure/aks/virtual-nodes-cli

# AKS can leverage Azure Container Instance (ACI) to expand the cluster capacity through on-demand provisioning
# of virtual nodes and pay per second for these expanded capacity
# Virtual Nodes are provisioned in the subnet to allow communication between Virtual Nodes and AKS nodes
# Check the above documentations for full details and the known limitations

# Make sure that you check the regional availability for this service in the documentation above.

# To use virtual nodes, you need AKS advanced networking enabled. Which we did
# Also we have setup a subnet to be used by virtual nodes and assigned access to AKS SP account.

# Make sure you have ACI provider registered
az provider list --query "[?contains(namespace,'Microsoft.ContainerInstance')]" -o table

# If not, you can register it now:
# az provider register --namespace Microsoft.ContainerInstance

# Now to activate it, you can execute the following command:
az aks enable-addons \
    --resource-group $RG_AKS \
    --name $AKS_CLUSTER_NAME \
    --addons virtual-node \
    --subnet-name $VNSUBNET_NAME

# Note: Virtual Nodes will not work with enabled cluster auto scaler on the (default node pool).
# You can disable it (if you got the error with this command)
# NODEPOOL_NAME=$AKS_DEFAULT_NODEPOOL
# az aks nodepool update \
#     --resource-group $RG_AKS \
#     --cluster-name $AKS_CLUSTER_NAME \
#     --name $NODEPOOL_NAME \
#     --disable-cluster-autoscaler

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
# kubernetes nodeSelector and toleration in your deployment manifest like:
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
az aks disable-addons --resource-group $RG_AKS --name $AKS_CLUSTER_NAME --addons virtual-node

# Container Registry Authentication for Virtual Nodes and ACI
# As basically virtual nodes are provisioned through ACI outside of the cluster, you need
# to setup your deployments/pods that target the virtual nodes with imagePullSecrets (as a workaround until full ACI integration with AKS SP or the use of managed identity go GA)

# You can use kubectl to create the secret :)
# Docs: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line
# kubectl create secret docker-registry acrImagePullSecret --docker-server=<your-acr-server> --docker-username=<sp id> --docker-password=<sp password> --docker-email=<optional email>

# You can inspect the secret easily via
# kubectl get secret acrImagePullSecret --output=yaml
# To have it in readable format use:
# kubectl get secret acrImagePullSecret --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode

# Finally, you need to update your deployment manifest under your container pod specs to use the imagePullSecrets:
# spec:
#   containers:
#   - name: <container-name>
#     image: <qualified image url on ACR>
#   imagePullSecrets:
#   - name: acrImagePullSecret

#***** Helm Configuration ******
# Assuming that helm client is installed. If not you can follow online instruction to install it.
# If you need information about installing helm check this https://docs.helm.sh/using_helm/#installing-helm
# I'm currently using v2.16.1
helm version

# If you want to upgrade helm, I used brew on WSL
# NOTE: Becarefull with the below command as it will upgrade helm to latest version which as of now 3.1.0
# brew upgrade kubernetes-helm
# to downgrade to helm 2, follow this: https://medium.com/@nehaguptag/installing-older-version-of-helm-downgrading-helm-8f3240592202

# Installing Tiller (helm server side client) on the AKS cluster
# First, check the role and service account that will be used by tiller
# The below deployment assign tiller a cluster-admin role
# Note: I would not recommend using this a cluster-admin bound tiller unless there is a specific need
# We will use the cluster-tiller to deploy App Gateway Ingress Controller and other cluster wide services
cat ./deployments/helm-admin-rbac.yaml

# If you need further control over tiller access (highly recommended), the custom rbac creates custom role 
# and bind it to tiller service account
more ./deployments/helm-dev-rbac.yaml
more ./deployments/helm-sre-rbac.yaml

# As Helm will use the current configured context for kubectl, let's make sure the right context is set (admin)
kubectl config get-contexts

# Cluster-Tiller SA: 
# Now we can use that SA to initialize tiller with that service account using helm client
# Creating a SA (Service Account) to be used by tiller in RBAC enabled clusters with cluster-admin role
# Using TLS is highly recommended through --tiller-tls-verify. You can refer back to helm documentation for how to generate 
# the required certificates
kubectl apply -f ./deployments/helm-admin-rbac.yaml
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

kubectl apply -f ./deployments/helm-dev-rbac.yaml
helm init --service-account tiller-dev --tiller-namespace dev

# Check if tiller is running in the dev namespace
kubectl get po --namespace dev

# SRE-Tiller
# Creating a SA (Service Account) to be used by tiller in RBAC enabled clusters with custom role
# Create the sre namespace if you didn't do already in previous steps
kubectl create namespace sre

kubectl apply -f ./deployments/helm-sre-rbac.yaml
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

# Token must be decoded from base64 encoding so it can be sorted in the config file. 
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

# We will need the endpoint when we construct our new configuration file
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
    --kubeconfig=$KUBE_CONF_FILE_NAME #WARNING! Permanent deletion

# To view the created conf file, navigate to the export folder and read the conf file
cd "${EXPORT_FOLDER}" #OPTIONAL. You will find the ca.crt and config file
ls -l
# You should see something like:
# -rw-rw-rw- 1 localadmin localadmin 1716 Oct  2 10:01 ca.crt
# -rw------- 1 localadmin localadmin 6317 Oct  2 10:03 k8s-tiller-dev-conf

# The config file then can be securely copied to CI/CD pipeline
# Incase of Azure DevOps, you can create a new Kubernetes Service connection under the project settings using this kubeconfig file. 
# Don't worry if you get forbidden error as the test tries to get all namespaces pods :)
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


echo "AKS-Post-Provision Scripts Execution Completed"