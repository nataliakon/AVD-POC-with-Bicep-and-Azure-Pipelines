// ----------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------

@description('General Purpose Storage Account Name')
param name string

@description('Key/Value pair of tags.')
param tags object = {}

//@description('Private Endpoint Subnet Id')
//param privateEndpointSubnetId string

@description('Private DNS Zone Resource Group for file.')
param filePrivateZoneRG string

param VnetResourceGroup string
param VnetName string
param subnetName string

@description('Allow large file shares if sets to Enabled. It cannot be disabled once it is enabled.')
param largeFileSharesState string = 'Enabled'


@description('Default Network Acls.  Default: deny')
param defaultNetworkAcls string = 'deny'

@description('Bypass Network Acls.  Default: AzureServices,Logging,Metrics')
param bypassNetworkAcls string = 'AzureServices,Logging,Metrics'

@description('Array of Subnet Resource Ids for Virtual Network Access')
param subnetIdForVnetAccess array = []

param LGAworspaceId string

var filePrivateZoneId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${filePrivateZoneRG}/providers/Microsoft.Network/privateDnsZones/privatelink.file.${environment().suffixes.storage}'
var privateEndpointSubnetId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${VnetResourceGroup}/providers/Microsoft.Network/virtualNetworks/${VnetName}/subnets/${subnetName}'


/* Storage Account */
resource storage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  tags: tags
  location: resourceGroup().location
  name: name
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    isHnsEnabled: false
    minimumTlsVersion: 'TLS1_2'
    largeFileSharesState: largeFileSharesState
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    encryption: {
      requireInfrastructureEncryption: true
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Account'
        }
        table: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    networkAcls: {
      defaultAction: defaultNetworkAcls
      bypass: bypassNetworkAcls
      virtualNetworkRules: [for subnetId in subnetIdForVnetAccess: {
        id: subnetId
        action: 'Allow'
      }]
    }
  }
}

resource threatProtection 'Microsoft.Security/advancedThreatProtectionSettings@2019-01-01' = {
  name: 'current'
  scope: storage
  properties: {
    isEnabled: true
  }
}

/* File Services */

resource fileservice 'Microsoft.Storage/storageAccounts/fileServices@2021-06-01' ={
  name: '${name}/default'
  properties: {
    
  }
  dependsOn: [
    storage
  ]
}



/* Private Endpoints */

resource storage_file_pe 'Microsoft.Network/privateEndpoints@2020-06-01' = if (!empty(filePrivateZoneRG)) {
  location: resourceGroup().location
  name: '${storage.name}-file-endpoint'
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storage.name}-file-endpoint'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }

  resource storage_file_pe_dns_reg 'privateDnsZoneGroups@2020-06-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink_file_core_windows_net'
          properties: {
            privateDnsZoneId: filePrivateZoneId
          }
        }
      ]
    }
  }
}



// Outputs
output storageName string = storage.name
output storageId string = storage.id
output storagePath string = storage.properties.primaryEndpoints.file
