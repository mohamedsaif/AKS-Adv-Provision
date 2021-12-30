# AKS-Adv-Provision

My views on deploying AKS with advanced provisions for development and production environments. 

![aks-architecture](res/aks-private-ref-architecture1.0.2.png)

## Provisioning Scripts and Configuration

Under [provisioning-v2](/provisioning-v2) folder you will find all deployment scripts and configuration. 

I've put all the commands in a numbered sequential shell scripts in the folder.

You can fork the repo and update the scripts with your customizations

> **NOTE:** This is a work on progress and will keep improving when I can to include recently released AKS features and versions

Currently the scripts applied to:
- Azure CLI version 2.0.81
- AKS Kubernetes version 1.15.7 (1.17.0 latest AKS preview)
- kubectl version 1.16.3
- helm version 2.16.0 (to be updated to 3 🤞)

## Using this repo

Everyone needs are different, this script was designed to cover wide range of topics and practices.

You need to make a version that suite your particular needs and scenario.

This is a suggested logical flow:

1. First you need to Fork or clone the repository.
2. Run through the [provisioning-v2/02-variables.sh](provisioning-v2/02-variables.sh) and update the values to suite your needs
    - Make sure you update the prefix and location
    - Make sure you update the network IP ranges
    - Generally run through all the variables and update them accordingly
3. Login to Azure via Azure CLI ```az login``` and set your correct active subscription
4. Review the [provisioning-v2/04-preview-providers.sh](provisioning-v2/04-preview-providers.sh) to check if you will be opting in any of the preview features
5. Create Azure [provisioning-v2/05-tags.sh](provisioning-v2/05-tags.sh) that will be used to tag all the different resources created by the script. Feel free to update (but be careful if you made changes that will required additional changes in other scripts)
6. Create [provisioning-v2/06-resource-groups.sh](provisioning-v2/06-resource-groups.sh)
    - Review the file as it will create 3 resource groups for your deployment (hub, project and share resource groups)
7. Start carefully review every script after to check what is being created and make a decision to use or not. Files are numbered to indicate a suggested logical order
8. Once you did the full run and your AKS cluster is provisioned, I would recommend having a consolidated new scripts that represent your deployment.
9. Once you are comfortable with the deployment, you can use the [provisioning-v2/01-main.sh](provisioning-v2/01-main.sh) to centrally run all the scripts sequentially to create the environnement from scratch.
    - You can delete the existing 3 resource groups or update the variable prefix to build another environment.
    - You can create multiple main.sh files to represent grouped related scripts execution
10. If you are comfortable with your final script, generate a guide document related to your deployment
11. Now it is time to plan true automation via Azure Resource Manager (ARM) or Terraform templates. Make sure you use source control to keep track of your changes.
12. Integrate your templates with DevOps pipeline.
13. Plan you workloads deployment on the newly certified AKS environment
14. Establish a review cycle (once every 3-5 months) to adjust the AKS deployment parameters and architecture to take advantage of all newly released features.

## AKS Permissions

Now let's talk permissions when creating and operating AKS clusters.

You have 4 permissions dimensions at play here:
- Provisioner permissions: who creates the needed infrastructure services for AKS
- [AKS identities permissions](https://docs.microsoft.com/en-us/azure/aks/use-managed-identity): recommended to use managed identities by AKS service to authenticate against Azure to maintain in-scope services (mainly the control plane and kubelet identity + identities for enabled add-ons)
- Operator permissions: who manages the cluster post provision
- In-cluster permissions: once you signed in into the cluster permissions (leveraging Kubernetes RBAC) and depends on wither you are using AAD integrated cluster or not 

>**NOTE:** It is useful to have a look at [Access and identity options for AKS](https://docs.microsoft.com/en-us/azure/aks/concepts-identity) docs for additional context.

In enterprise scenarios, creating an AKS cluster require few services to be up and running before the creation of the cluster with required permissions already been assigned.

As there are many ways to setup you AKS cluster preferences, I will focus on the approach that I think to fit most scenarios.

If you have multi provisioner teams setup, I would recommend the following:
- Network team: to create/update virtual network setup for the target cluster (AKS requires at lest one subnet with with appropriate peering, DNS, user defined routes,...)
- Security team: to create a managed identity for the cluster and assign appropriate permissions to both the provisioner of AKS and the control plane managed identity
- Service infra team: to create the AKS cluster according to requirements
- Service operations team: to operate and maintain cluster after provisioning

The following components are usually shared:

- Virtual Network (subnets, DNS, peering, user defined routes, NSGs,...)
- Outbound Public IP (if --outboundType loadBalancer default value is used)
- Network firewall (like Azure Firewall configured with required egress rules)
- Log Analytics workspace (can be central across multiple services or specific to each cluster/spoke deployments)
- Cluster's control plan managed identity
- Application gateway (if App Gateway Ingress Controller will be used)
- Central private dns zone (if private cluster is enabled)
- Azure container registry

#### Permissions summery:

- Network

Identity | Service | Permission | Notes
---|---|---|---
AKS Control Plane MI | vnet/subnet | Network Contributor | If you use private AKS cluster, you need network contributor at the vnet level, if not, Network Contributor on the subnet(s) level is sufficient. You might use multiple subnets with AKS so keep that in mind with permissions
AKS Control Plane MI | private dns | Private DNS Zone Contributor | If you use private AKS cluster with central private dns zone
AKS Provision (user or Service Principal) | subnet | Network Contributor | Provisioner account will perform Microsoft.Authorization/roleAssignments/read and Microsoft.Network/virtualNetworks/subnets/join/action on the primary subnet of the AKS cluster during creation
AKS Provision (user or Service Principal) | Public IP (outbound) | Network Contributor | This required if you use --outboundType loadBalancer and will be assigning specific public IP to be used by the cluster

- AKS

Identity | Service | Permission | Notes
---|---|---|---
AKS Provision (user or Service Principal) | Resource Group | Azure Kubernetes Service Contributor Role | This permission will permit read and write of AKS clusters on target resource group

- Other resources

Depending on what add-ons you enable on the cluster you might need additional permissions to be granted.

For example, if you enabled **Monitoring** add-on, permission over the target log analytics workspace is required 

## Provisioning v2 Structure

I separated the provisioning of v1 style into separate files for better locating the information related to AKS.

The current files structure for v2 to is:

```bash

/provisioning-v2
.
├── 00-template.sh
├── 01-main.sh
├── 02-variables.sh
├── 03-login.sh
├── 04-preview-providers.sh
├── 05-tags.sh
├── 06-resource-groups.sh
├── 07-monitoring.sh
├── 08-key-vault.sh
├── 09-virtual-network.sh
├── 10-app-gateway.sh
├── 11-jump-box.sh
├── 12-apim.sh
├── 13-container-registry.sh
├── 14-aks-pip.sh
├── 15-aad-aks-sp.sh
├── 16-aad-aks-auth.sh
├── 17-aks.sh
├── 18-aks-post-provision.sh
├── 19-aks-add-role-binding.sh
├── 20-aks-node-pools.sh
├── 21-pod-identity.sh
├── 22-agic.sh
├── 23-azure-firewall.sh
├── 24-aks-policy.sh
├── 25-aks-maintenance.sh
├── 26-traffic-manager.sh
├── deployments
│   ├── aad-pod-identity-binding.yaml
│   ├── aad-pod-identity.yaml
│   ├── aad-user-cluster-admin-binding.yaml
│   ├── agic-helm-config.yaml
│   ├── agic-sp-helm-config.yaml
│   ├── apim-deployment.json
│   ├── dashboard-proxy-binding.yaml
│   ├── helm-admin-rbac.yaml
│   ├── helm-dev-rbac.yaml
│   ├── helm-sre-rbac.yaml
│   ├── logs-workspace-deployment.json
│   ├── monitoring-log-reader-rbac.yaml
│   ├── nginx-deployment.yaml
│   ├── nginx-ingress-deployment.yaml
│   └── nginx-ingress-tls-deployment.yaml

```

## About the project

I tried to make sure I cover all aspects and best practices while building this project, but all included architecture, code, documentation and any other artifact represent my personal opinion only. Think of it as a suggestion of how a one way things can work.

Keep in mind that this is a work-in-progress, I will continue to contribute to it when I can.

All constructive feedback is welcomed 🙏

## Support

You can always create issue, suggest an update through PR or direct message me on [Twitter](https://twitter.com/mohamedsaif101).

## Authors

|      ![Photo](res/mohamed-saif.jpg)            |
|:----------------------------------------------:|
|                 **Mohamed Saif**               |
|     [GitHub](https://github.com/mohamedsaif)   |
|  [Twitter](https://twitter.com/mohamedsaif101) |
|         [Blog](http://blog.mohamedsaif.com)    |