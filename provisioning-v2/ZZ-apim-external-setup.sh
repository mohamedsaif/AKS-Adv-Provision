#!/bin/bash

# Make sure that variables are updated
source ./$VAR_FILE

# Preparing host names
BASE_HOST=az.mobivisions.com
APIM_PORTAL_HOST=apim-portal-$LOCATION_CODE-$SUBSCRIPTION_CODE.$BASE_HOST
APIM_MANAGEMENT_HOST=apim-management-$LOCATION_CODE-$SUBSCRIPTION_CODE.$BASE_HOST
APIM_GATEWAY_HOST=apim-gateway-$LOCATION_CODE-$SUBSCRIPTION_CODE.$BASE_HOST
echo $APIM_PORTAL_HOST
echo $APIM_MANAGEMENT_HOST
echo $APIM_GATEWAY_HOST

AKV_INGRESS_HOST_NAME=${BASE_HOST//./-}
echo $AKV_INGRESS_HOST_NAME

echo export BASE_HOST=$BASE_HOST >> ./$VAR_FILE
echo export APIM_PORTAL_HOST=$APIM_PORTAL_HOST >> ./$VAR_FILE
echo export APIM_MANAGEMENT_HOST=$APIM_MANAGEMENT_HOST >> ./$VAR_FILE
echo export APIM_GATEWAY_HOST=$APIM_GATEWAY_HOST >> ./$VAR_FILE
echo export AKV_INGRESS_HOST_NAME=$AKV_INGRESS_HOST_NAME >> ./$VAR_FILE

#######################################
# Pointing required host names to DNS #
#######################################

# This assumes you have delegated public DNS zone to Azure DNS in specified below resource group
DNS_RG=connectivity
DNS_NAME=$BASE_HOST

AGW_PIP_ADDRESS=$(az network public-ip show \
  --resource-group $RG_INFOSEC \
  --name $AGW_PIP_NAME \
  --query ipAddress \
  -o tsv)
echo $AGW_PIP_ADDRESS
echo export AGW_PIP_ADDRESS=$AGW_PIP_ADDRESS >> ./$VAR_FILE

# Main gateway
az network dns record-set a add-record \
  -g $DNS_RG \
  -z $DNS_NAME \
  -n apim-gateway-$LOCATION_CODE-$SUBSCRIPTION_CODE \
  -a $AGW_PIP_ADDRESS

# Publishing portal require both portal and management endpoints:
az network dns record-set a add-record \
  -g $DNS_RG \
  -z $DNS_NAME \
  -n apim-portal-$LOCATION_CODE-$SUBSCRIPTION_CODE \
  -a $AGW_PIP_ADDRESS

az network dns record-set a add-record \
  -g $DNS_RG \
  -z $DNS_NAME \
  -n apim-management-$LOCATION_CODE-$SUBSCRIPTION_CODE \
  -a $AGW_PIP_ADDRESS

###############
# Self-signed #
###############
# Adding certificate to Key Vault

# either have a CA issued certificate ready or generate self-signed one
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#   -out $AKV_INGRESS_HOST_NAME-tls.crt \
#   -keyout $AKV_INGRESS_HOST_NAME-tls.key \
#   -subj "/CN=*.$BASE_HOST"

# If you are creating cert as Key vault secret, generate pfx without password
# openssl pkcs12 -export \
#   -in $AKV_INGRESS_HOST_NAME-tls.crt \
#   -inkey $AKV_INGRESS_HOST_NAME-tls.key \
#   -passout pass: -out $AKV_INGRESS_HOST_NAME-cert.pfx
# Creating cert as secret:
# AKV_CERT_VALUE=$(cat $AKV_INGRESS_HOST_NAME-cert.pfx | base64)
# az keyvault secret set --vault-name $KEY_VAULT_PRIMARY --name $AKV_INGRESS_HOST_NAME --value ${AKV_CERT_VALUE}

##################
# Importing cert #
##################
# If you are creating cert as Key vault certificate, generate pfx with password
# openssl pkcs12 -export \
#   -in $AKV_INGRESS_HOST_NAME-tls.crt \
#   -inkey $AKV_INGRESS_HOST_NAME-tls.key \
#   -out $AKV_INGRESS_HOST_NAME-cert.pfx

CERT_PASSWORD=
az keyvault certificate import \
  --vault-name $KEY_VAULT_PRIMARY \
  -n $AKV_INGRESS_HOST_NAME-cert \
  -f $AKV_INGRESS_HOST_NAME-cert.pfx \
  --password $CERT_PASSWORD

# Adding Key Vault certificate to App Gateway
AKV_CERT_ID=$(az keyvault certificate show \
  --vault-name $KEY_VAULT_PRIMARY \
  -n $AKV_INGRESS_HOST_NAME-cert \
  --query sid \
  -o tsv)
echo $AKV_CERT_ID
AKV_CERT_ID_NO_VERSION=${AKV_CERT_ID%/*}
echo $AKV_CERT_ID_NO_VERSION

echo export AKV_CERT_ID=$AKV_CERT_ID >> ./$VAR_FILE
echo export AKV_CERT_ID_NO_VERSION=$AKV_CERT_ID_NO_VERSION >> ./$VAR_FILE

az network application-gateway ssl-cert create \
  --resource-group $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n $AKV_INGRESS_HOST_NAME \
  --key-vault-secret-id $AKV_CERT_ID_NO_VERSION

# Creating Ports
az network application-gateway frontend-port create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n https \
  --port 443

# Creating listeners (on public ip)
FL_APIM_PORTAL=fl-apim-portal
FL_APIM_MANAGEMENT=fl-apim-management
FL_APIM_GATEWAY=fl-apim-gateway

az network application-gateway http-listener create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  --frontend-port https \
  -n $FL_APIM_PORTAL \
  --host-name $APIM_PORTAL_HOST \
  --ssl-cert $AKV_INGRESS_HOST_NAME \
  --waf-policy $AGW_WAF_POLICY_NAME \
  --frontend-ip appGatewayFrontendIP

az network application-gateway http-listener create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  --frontend-port https \
  -n $FL_APIM_MANAGEMENT \
  --host-name $APIM_MANAGEMENT_HOST \
  --ssl-cert $AKV_INGRESS_HOST_NAME \
  --waf-policy $AGW_WAF_POLICY_NAME \
  --frontend-ip appGatewayFrontendIP

az network application-gateway http-listener create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  --frontend-port https \
  -n $FL_APIM_GATEWAY \
  --host-name $APIM_GATEWAY_HOST \
  --ssl-cert $AKV_INGRESS_HOST_NAME \
  --waf-policy $AGW_WAF_POLICY_NAME \
  --frontend-ip appGatewayFrontendIP

# Creating backend pools using IP or FQDN (FQDN commended out)

az network application-gateway address-pool create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n apim-hub \
  --servers $APIM_PRIVATE_IP

# az network application-gateway address-pool create \
#   -g $RG_INFOSEC \
#   --gateway-name $AGW_NAME \
#   -n apim-portal \
#   --servers $APIM_NAME.developer.azure-api.net

# az network application-gateway address-pool create \
#   -g $RG_INFOSEC \
#   --gateway-name $AGW_NAME \
#   -n apim-management \
#   --servers $APIM_NAME.management.azure-api.net

# az network application-gateway address-pool create \
#   -g $RG_INFOSEC \
#   --gateway-name $AGW_NAME \
#   -n apim-gateway \
#   --servers $APIM_NAME.azure-api.net

# creating health prop
az network application-gateway probe create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n hp-apim-portal \
  --protocol https \
  --host-name-from-http-settings true \
  --path "/SignIn"

az network application-gateway probe create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n hp-apim-management \
  --protocol https \
  --host-name-from-http-settings true \
  --path "/ServiceStatus"
# https://devglb-apim-vsen-weu.management.azure-api.net:3443/servicestatus?api-version=2018-01-01

az network application-gateway probe create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n hp-apim-gateway \
  --protocol https \
  --host-name-from-http-settings true \
  --path "/status-0123456789abcdef"

# creating backend setting
az network application-gateway http-settings create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n bs-apim-portal \
  --port 443 \
  --protocol Https \
  --cookie-based-affinity Disabled \
  --timeout 30 \
  --host-name-from-backend-pool false \
  --host-name $APIM_NAME.developer.azure-api.net \
  --probe hp-apim-portal

az network application-gateway http-settings create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n bs-apim-management \
  --port 443 \
  --protocol Https \
  --cookie-based-affinity Disabled \
  --timeout 30 \
  --host-name-from-backend-pool false \
  --host-name $APIM_NAME.management.azure-api.net \
  --probe hp-apim-management

az network application-gateway http-settings create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n bs-apim-gateway \
  --port 443 \
  --protocol Https \
  --cookie-based-affinity Disabled \
  --timeout 30 \
  --host-name-from-backend-pool false \
  --host-name $APIM_NAME.azure-api.net \
  --probe hp-apim-gateway

# creating routing rule

az network application-gateway rule create \
  --gateway-name $AGW_NAME \
  --name rr-apim-portal \
  --resource-group $RG_INFOSEC \
  --address-pool apim-hub \
  --http-listener $FL_APIM_PORTAL \
  --http-settings bs-apim-portal \
  --priority 100 \
  --rule-type basic

az network application-gateway rule create \
  --gateway-name $AGW_NAME \
  --name rr-apim-management \
  --resource-group $RG_INFOSEC \
  --address-pool apim-hub \
  --http-listener $FL_APIM_MANAGEMENT \
  --http-settings bs-apim-management \
  --priority 110 \
  --rule-type basic

az network application-gateway rule create \
  --gateway-name $AGW_NAME \
  --name rr-apim-gateway \
  --resource-group $RG_INFOSEC \
  --address-pool apim-hub \
  --http-listener $FL_APIM_GATEWAY \
  --http-settings bs-apim-gateway \
  --priority 120 \
  --rule-type basic

# az network application-gateway rule create \
#   --gateway-name $AGW_NAME \
#   --name rr-apim-portal \
#   --resource-group $RG_INFOSEC \
#   --address-pool apim-portal \
#   --http-listener $FL_APIM_PORTAL \
#   --http-settings bs-apim-portal \
#   --priority 100 \
#   --rule-type basic

# az network application-gateway rule create \
#   --gateway-name $AGW_NAME \
#   --name rr-apim-management \
#   --resource-group $RG_INFOSEC \
#   --address-pool apim-management \
#   --http-listener $FL_APIM_MANAGEMENT \
#   --http-settings bs-apim-management \
#   --priority 110 \
#   --rule-type basic

# az network application-gateway rule create \
#   --gateway-name $AGW_NAME \
#   --name rr-apim-gateway \
#   --resource-group $RG_INFOSEC \
#   --address-pool apim-gateway \
#   --http-listener $FL_APIM_GATEWAY \
#   --http-settings bs-apim-gateway \
#   --priority 120 \
#   --rule-type basic

# Above settings will work out of the box with the gateway, but Portal and Management, will require setting
# custom domains on apim

# Installing backend routing for custom workload:

##############################
# Creating Project Key Vault #
##############################

# Creating project specific Azure Key Vault to be used
AKV_SPOKE_NAME=${PREFIX}-${SUBSCRIPTION_CODE}-${LOCATION_CODE}-akv
AKV_SPOKE_ID=$(az keyvault create \
    --name $AKV_SPOKE_NAME \
    --resource-group $RG_SHARED \
    --location $LOCATION \
    --tags $TAG_ENV $TAG_PROJ_SHARED $TAG_DEPT_IT $TAG_STATUS_EXP \
    --query id -o tsv)
echo $AKV_SPOKE_ID

az network private-endpoint create \
    --resource-group $RG_SHARED \
    --vnet-name $PROJ_VNET_NAME \
    --subnet $PRIVATE_ENDPOINTS_SUBNET_NAME \
    --name pe-$AKV_SPOKE_NAME \
    --private-connection-resource-id $AKV_SPOKE_ID \
    --group-id vault \
    --connection-name shared-keyvault-connection \
    --location $LOCATION

az network private-dns zone create \
    --resource-group $RG_SHARED \
    --name "privatelink.vaultcore.azure.net"

az network private-dns link vnet create \
    --resource-group $RG_SHARED \
    --zone-name "privatelink.vaultcore.azure.net" \
    --name KeyVaultDNSLink \
    --virtual-network $PROJ_VNET_NAME \
    --registration-enabled false
# Optional to link hub as well
az network private-dns link vnet create \
    --resource-group $RG_SHARED \
    --zone-name "privatelink.vaultcore.azure.net" \
    --name KeyVaultDNSLink \
    --virtual-network $HUB_EXT_VNET_NAME \
    --registration-enabled false

KEYVAULT_NIC_ID=$(az network private-endpoint show --name pe-$AKV_SPOKE_NAME --resource-group $RG_SHARED --query 'networkInterfaces[0].id' -o tsv)
AKV_SPOKE_NIC_IPADDRESS=$(az resource show --ids $KEYVAULT_NIC_ID --api-version 2019-04-01 -o json | jq -r '.properties.ipConfigurations[0].properties.privateIPAddress')
echo $AKV_SPOKE_NIC_IPADDRESS

az network private-dns record-set a add-record -g $RG_SHARED -z "privatelink.vaultcore.azure.net" -n $AKV_SPOKE_NAME -a $AKV_SPOKE_NIC_IPADDRESS
# az network private-dns record-set list -g $RG_SHARED -z "privatelink.vaultcore.azure.net" -o table

echo export AKV_SPOKE_ID=$AKV_SPOKE_ID >> ./$VAR_FILE
echo export AKV_SPOKE_NIC_IPADDRESS=$AKV_SPOKE_NIC_IPADDRESS >> ./$VAR_FILE

# Creating managed identity to access the key vault, or use the default identity provided by AKS secrets CSI driver
KV_MI=$(az aks show -g $RG_AKS -n $AKS_CLUSTER_NAME --query addonProfiles.azureKeyvaultSecretsProvider.identity.objectId -o tsv)
echo $KV_MI
TENANT_ID=$(az account show --query tenantId -o tsv)
echo $TENANT_ID
az keyvault set-policy \
    --name $AKV_SPOKE_NAME \
    --resource-group $RG_SHARED \
    --object-id $KV_MI \
    --secret-permissions get list \
    --certificate-permissions get list

CERT_NAME=eshop-$LOCATION_CODE-$SUBSCRIPTION_CODE-$AKV_INGRESS_HOST_NAME
CERT_CN=eshop-$LOCATION_CODE-$SUBSCRIPTION_CODE.$BASE_HOST
echo $CERT_NAME
echo $CERT_CN
mkdir certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -out certs/$CERT_NAME-tls.crt \
    -keyout certs/$CERT_NAME-tls.key \
    -subj "/CN=$CERT_CN/O=ingress-tls"

openssl pkcs12 -export -in certs/$CERT_NAME-tls.crt -inkey certs/$CERT_NAME-tls.key  -out certs/$CERT_NAME.pfx
# skip Password prompt

CERT_PASSWORD=
az keyvault certificate import \
  --vault-name $AKV_SPOKE_NAME \
  -n $CERT_NAME \
  -f certs/$CERT_NAME.pfx \
  --password $CERT_PASSWORD

INGRESS_PRIVATE_IP=10.165.20.4
INGRESS_DNS_RECORD=eshop-weu-mcaps
INGRESS_HOST_NAME=eshop-weu-mcaps.$BASE_HOST
APP_NS=eshop
# Adding AKV cert to inginx ingress for end-to-end
cat << EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: $AKV_INGRESS_HOST_NAME-tls-spc
  namespace: $APP_NS
spec:
  provider: azure
  secretObjects:                            # secretObjects defines the desired state of synced K8s secret objects
  - secretName: $AKV_INGRESS_HOST_NAME-tls-csi
    type: kubernetes.io/tls
    data: 
    - objectName: $CERT_NAME
      key: tls.key
    - objectName: $CERT_NAME
      key: tls.crt
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"          # Set to true for using managed identity
    userAssignedIdentityID: $KV_MI   # Set the clientID of the user-assigned managed identity to use
    keyvaultName: $AKV_SPOKE_NAME                 # the name of the AKV instance
    objects: |
      array:
        - |
          objectName: $CERT_NAME
          objectType: secret
    tenantId: $TENANT_ID                    # the tenant ID of the AKV instance
EOF

# Updating nginx deployment to use the new AKV certificate
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --set controller.replicaCount=1 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    -f - <<EOF
controller:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "devglb-ingress"
  extraVolumes:
      - name: secrets-store-inline
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: $AKV_INGRESS_HOST_NAME-tls-spc
  extraVolumeMounts:
      - name: secrets-store-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
EOF

# validate the creation of AKV based kubernetes secrets
kubectl get secrets -n $APP_NS  

# Adding new ingress host name to public DNS
az network dns record-set a add-record \
  -g $DNS_RG \
  -z $BASE_HOST \
  -n $INGRESS_DNS_RECORD \
  -a $AGW_PIP_ADDRESS

az network application-gateway address-pool create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n eshop-platform \
  --servers $INGRESS_PRIVATE_IP

# Using HTTP
az network application-gateway probe create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n hp-eshop-platform \
  --protocol http \
  --host-name-from-http-settings true \
  --path "/webstatus/hc-ui"

az network application-gateway http-settings create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  -n bs-eshop-platform \
  --port 80 \
  --protocol Http \
  --cookie-based-affinity Disabled \
  --timeout 30 \
  --host-name-from-backend-pool false \
  --host-name $INGRESS_HOST_NAME \
  --probe hp-eshop-platform

# Using HTTPS for end to end encryption
# az network application-gateway probe create \
#   -g $RG_INFOSEC \
#   --gateway-name $AGW_NAME \
#   -n hp-eshop-platform \
#   --protocol https \
#   --host-name-from-http-settings true \
#   --path "/webstatus/hc-ui"

# az network application-gateway http-settings create \
#   -g $RG_INFOSEC \
#   --gateway-name $AGW_NAME \
#   -n bs-eshop-platform \
#   --port 443 \
#   --protocol Https \
#   --cookie-based-affinity Disabled \
#   --timeout 30 \
#   --host-name-from-backend-pool false \
#   --host-name $INGRESS_HOST_NAME \
#   --probe hp-eshop-platform

az network application-gateway http-listener create \
  -g $RG_INFOSEC \
  --gateway-name $AGW_NAME \
  --frontend-port https \
  -n fl-eshop-platform \
  --host-name $INGRESS_HOST_NAME \
  --ssl-cert $AKV_INGRESS_HOST_NAME \
  --waf-policy $AGW_WAF_POLICY_NAME \
  --frontend-ip appGatewayFrontendIP

az network application-gateway rule create \
  --gateway-name $AGW_NAME \
  --name rr-eshop-platform \
  --resource-group $RG_INFOSEC \
  --address-pool eshop-platform \
  --http-listener fl-eshop-platform \
  --http-settings bs-eshop-platform \
  --priority 130 \
  --rule-type basic


echo "Template Scripts Execution Completed"

# volumes:
#     - name: secrets-store-inline
#       csi:
#         driver: secrets-store.csi.k8s.io
#         readOnly: true
#         volumeAttributes:
#           secretProviderClass: az-mobivisions-com-tls-spc

# volumeMounts:
#         - name: secrets-store-inline
#           readOnly: true
#           mountPath: /mnt/secrets-store