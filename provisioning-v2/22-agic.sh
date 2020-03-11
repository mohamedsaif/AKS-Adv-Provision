#!/bin/bash

# Make sure that variables are updated
source ./aks.vars

#***** App Gateway Ingress Controller Provisioning *****

# Docs: https://github.com/Azure/application-gateway-kubernetes-ingress 
# Greenfield Deployment: https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/setup/install-new.md
# Brownfield Deployment: https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/setup/install-existing.md
# You can provision the AGIC either through using AAD Pod Identity or SP. As best practice, I'm using Pod Identity.

AGW_IDENTITY_NAME="${PREFIX}-agw-identity"

# Provision the app gateway
# Note to maintain SLA, you need to set --min-capacity to at least 2 instances
# Azure Application Gateway must be v2 SKUs
# App Gateway will be used as ingress controller: https://azure.github.io/application-gateway-kubernetes-ingress/
# In earlier step we provisioned a vNet with a subnet dedicated for App Gateway and the application gateway v2.

# We need the resource id in order to assign role to AGW managed identity
AGW_RESOURCE_ID=$(az network application-gateway show --name $AGW_NAME --resource-group $RG_INFOSEC --query id --output tsv)
echo $AGW_RESOURCE_ID

# Installing App Gateway Ingress Controller
# Setup Documentation on existing cluster: https://azure.github.io/application-gateway-kubernetes-ingress/setup/install-existing/
# Setup Documentation on new cluster: https://azure.github.io/application-gateway-kubernetes-ingress/setup/install-new/

# Make sure helm is installed (for kube-system). Steps for helm preparation mentioned above
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
# 2. Service exposing the nginx deployment via internal loadbalancer. Service is deployed in the services subnet created earlier
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

# If you need to check the deployment, pods or services provisioned, use these popular kubectl commands:
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
AGW_PUBLICIP_ADDRESS=$(az network public-ip show -g $RG_INFOSEC -n $AGW_PIP_NAME --query ipAddress -o tsv)
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
# If successful, the service will be available via both HTTP and HTTPS

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

#***** END App Gateway Provisioning *****

echo "AGIC Scripts Execution Completed"