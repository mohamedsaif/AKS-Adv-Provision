#!/bin/bash

# If you have a private cluster, make sure you are connecting via jump-box or have VPN connectivity to the vnet

# Make sure that variables are updated
source ./$VAR_FILE


# DEMO
### Testing with simple nginx deployment (pod, service and ingress)
# The following manifest will create:
# 1. A deployment named nginx (basic nginx deployment)
# 2. Service exposing the nginx deployment via internal loadbalancer. Service is deployed in the services subnet created earlier
# 3. Ingress to expose the service via App Gateway public IP (using AGIC)

# Before applying the file, we just need to update it with our services subnet we created earlier :)
sed ./deployments/nginx-deployment.yaml \
    -e s/SVCSUBNET/$SVC_SUBNET_NAME/g \
    > ./deployments/nginx-deployment-updated.yaml

# Have a look at the test deployment:
cat ./deployments/nginx-deployment-updated.yaml

# Let's apply
kubectl apply -f ./deployments/nginx-deployment-updated.yaml

# Here you need to wait a bit to make sure that the service External (local) IP is assigned before applying the ingress controller
kubectl get service nginx-service
# NAME            TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
# nginx-service   LoadBalancer   10.41.139.83   10.42.2.4     80:31479/TCP   18m

# If you need to check the deployment, pods or services provisioned, use these popular kubectl commands:
kubectl get pods
# You should have 3 pods for the new deployment
# nginx-deployment-ccd7579cd-f8727   1/1     Running   0          3m34s
# nginx-deployment-ccd7579cd-np2c4   1/1     Running   0          3m34s
# nginx-deployment-ccd7579cd-t7tv8   1/1     Running   0          3m34s

# have a look inside the service description
kubectl describe svc nginx-service

# Now everything is good, let's apply the ingress
kubectl apply -f ./deployments/nginx-ingress-deployment.yaml

# Perform checks internally:
kubectl get ingress -w
# Wait until you get the IP address
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

echo "AGIC Demo Scripts Execution Completed"