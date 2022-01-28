# Multi-session Azure Virtual Desktop (AVD) Proof of Concept 

The repository provides the code to deploy Proof-of-Concept for Azure Virtual Desktop (AVD). The code is based on the simplified AVD pattern deployed in couple of Customers' environments. Included Azure Pipelines can be used for initial deployment as well as lifecycle tasks such as user assignment and host pool administration (updating hosts with new images or adding hosts). 

The proof-of-concept focuses on *pooled* session host pool deployments. Minor modifications can be done to adjust to *personal* mode if required. Application publishing via MSIX or Application groups is not covered here. 

The following assumptions are made: 

* Deployment is done to established Azure environment where essential [Azure Landing Zone(s)](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/) are established (i.e Hub-Spoke networking topology)
* [AVD requirements](https://docs.microsoft.com/azure/virtual-desktop/overview#requirements) are met
* If required using custom image - "gold" image is created and deployed to Azure Compute Gallery

## Table of Contents

* [AVD Design](#avd-design)
* [Azure Resource Groups](#azure-resource-groups)
* [User Guide](#user-guide)
* [Deployment Guide](#deployment-guide)


## AVD Design 

In general, enterprises prefer to breakdown the VDI management based on the Line of Business. Persona and Pod are logical units of measurement to simplify the management of Azure Virtual Desktop environment. 

***Persona*** or Workspace is equal to AVD Workspace. Personas are formed based on the end users’ requirements such as working style and usage pattern and aligned with Business Unit. 

***Pod*** or Application Group/Host pool is equal to department. Pods represent groups of users within Persona with similar usage patterns and network connectivity requirements. 

![AVD Design](/documentation/images/AVDdesign.png)

The objective is to keep the number of images/personas on smaller scale. Each persona is divided into Pods. The Pod could represent 150 users and consists of approximately min. 5 session hosts. However, the Pod sizing can vary based on the total number of users within persona and usage patterns. 

User profile management would be addressed via FSLogix profile containers with Azure Files as storage backend. The configuration values are set as part of provisioning. As the adoption of AVD increases and if user requirements for optimal performance – Azure NetApp files should be considered. 

## Azure Resource Groups 

The diagram below show the Resource Groups and Azure resources deployed as part of the Proof-of-Concept including the shared infrastructure:  

![AzureResources](/documentation/images/AzureResources.png)

#### Shared infrastucture Resource Group: 

* Azure Key Vault: contains credentials for local administrator and domain join credentials. As well as Host Pool registration info. 
* Log Analytics Workspace: diagnostics from AVD resources and session hosts. 
* Azure Storage Account for user profiles. Azure File Share per Pod for small scale POC should be sufficient. 
* Azure Virtual Network (VNET) can be either in the same resource group or deployed in separate subscription/resource group. Pod/Host Pool is deployed to its dedicated subnet. 
* [Optional] Deploy Azure Image Builder and Compute Gallery resources into the Shared Infrastructure Resource Group. Or reference the location in the Persona configuration file. 

##### *Note:  Azure Private DNS zone for Azure Files endpoints is required. The resource ID of the zone is required before inital deployment.* 

#### AVD Persona and its Pods Resource Group(s):

* Azure Storage Account with private endpoint
* Azure Virtual Desktop Workspace 
* Azure Virtual Desktop Application Group per Pod 
* Azure Virtual Desktop Host Pool per Pod

#### Session Hosts Resource Group(s): 

* Virtual machines for each Pod are to be provisioned into dedicated Resource Group.

## User Guide

Please see [User Guide](documentation/UserGuide.md) for Azure Pipelines overview and how to use the solution. 

## Deployment Guide

Please see [Deployment Guide](/documentation/DeploymentGuide.md)
