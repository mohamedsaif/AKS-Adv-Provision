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