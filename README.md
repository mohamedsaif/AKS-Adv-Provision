# AKS-Adv-Provision

My views on deploying AKS with advanced provisions for development and production environments. 

![aks-architecture](res/aks-architecture.png)

## Provisioning Scripts and Configuration

Under [provisioning-v2](/provisioning-v2) folder you will find all deployment scripts and configuration. 

I've put all the commands in a numbered sequential shell scripts in the folder.

You can fork the repo and update the scripts with your customizations

> **NOTE:** This is a work on progress and will keep improving when I can to include recently released AKS features and versions

Currently the scripts applied to:
- Azure CLI version 2.0.81
- AKS Kubernetes version 1.15.7 (1.17.0 latest AKS preview)
- kubectl version 1.16.3
- helm version 2.15.0 (to be updated to 3 🤞)

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