@description('Persona name')
param personaId string

@description('Pod ID') 
param podId string

@description('Key/Value pair of tags.')
param tags object = {}

param location string = resourceGroup().location
param hostPoolResourceGroup string 
param HostPoolName string = '${personaId}-${podId}-Pool'
param hostPoolLocation string = 'eastus'

param timezone string = 'Eastern Standard Time'
param vmSize string
param zones array = []
param instance_count int // number of sessions hosts to be added
param currentInstances int // number of existing current sessions hosts pools
param rdshprefix string = 'AVD${personaId}${podId}'
param storageAccountType string

param useSharedImage bool
param shared_image_gallery_rg string 
param shared_image_gallery_name string 
param shared_image_gallery_definition string

param joinDomain bool
param domainToJoin string
param ouPath string

param VaultName string
param VaultResourceGroupName string
param VaultSubscriptionId string

param VnetName string
param VnetResourceGroup string
param subnetName string

@description('The flag that enables or disables hibernation capability on the VM')
param hibernationEnabled bool = false

// @description(' Pre-requisite - subscription must be whitelisted for the feature .Enable or disable the Host Encryption for the virtual machine or virtual machine scale set. This will enable the encryption for all the disks including Resource/Temp disk at host itself.')
// param encryptionAtHost bool = false

param storageAccountName string
param storageResourceGroup string
param container string
param shareName string 
param personaStorageAccount string


var personaRG = 'AVD-${personaId}-RG'
var shareNamePath = toLower('\\\\${personaStorageAccount}.file.${environment().suffixes.storage}\\${shareName}')

/* Return the KeyVault for local admin credentials and host pool token */

resource keyvault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: VaultName
  scope: resourceGroup(VaultResourceGroupName)
}


resource personaStorage 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: personaStorageAccount
  scope: resourceGroup(personaRG)
}

var allZones = pickZones('Microsoft.Compute', 'virtualMachines', resourceGroup().location, 3)

/* Deploy VMs and NICs */

module vms 'compute/new-vms.bicep' = [for i in range(0, instance_count): {
  name: 'Deploy-VM${i+currentInstances+1}-to-${HostPoolName}'
  params: {
      index: i+currentInstances+1
      rdshPrefix: rdshprefix
      location: location
      tags: tags
      VnetName: VnetName
      VnetResourceGroup: VnetResourceGroup
      subnetName: subnetName
      vmSize: vmSize
      storageAccountType: storageAccountType
      shared_image_gallery_definition: shared_image_gallery_definition
      shared_image_gallery_name: shared_image_gallery_name
      shared_image_gallery_rg: shared_image_gallery_rg
      useSharedImage: useSharedImage
      adminPassword: keyvault.getSecret('localAdminPassword')
      adminUsername: keyvault.getSecret('localAdminUsername')
      timezone: timezone
      zones: zones == '' ? take(skip(allZones,i % length(allZones)),1) : array(zones)
      hibernationEnabled: hibernationEnabled 
      // encryptionAtHost: encryptionAtHost

  }
}]

/* Deploy Custom Extension  to configure FSLogix */

module configureFsLogix 'extensions/configure-fslogix.bicep' = [for i in range(0, instance_count): {
  name: 'Configure-FsLogix-for-VM${i+currentInstances+1}-in-${HostPoolName}'
  dependsOn: [
    addHostToHostPool
  ]
  params: {
    container: container
    index: i+currentInstances+1
    location: location
    rdshPrefix: rdshprefix
    shareName: shareNamePath
    storageaccountName: storageAccountName
    storageaccountRG: storageResourceGroup
  }
}]

/* Join domain via extension */

module joinToDomain 'extensions/join-domain.bicep' = [for i in range(0, instance_count): if (joinDomain)  {
  name: 'Join-VM${i+currentInstances+1}-To-Domain-${domainToJoin}'
  dependsOn: [
    vms
  ]
  params: {
  index: i+currentInstances+1
  rdshPrefix: rdshprefix
  location: location
  domainToJoin: domainToJoin
  joinDomainAccount: keyvault.getSecret('domainaccount')
  joinDomainPassword: keyvault.getSecret('domainpassword')
  ouPath: ouPath
  }
}]


// /* Add VMs to the Host Pool via DSC extension */

module addHostToHostPool 'extensions/add-to-hostPool-dcs.bicep' = [for i in range(0, instance_count): {
  name: 'Add-Host${i+currentInstances+1}-to-HostPool-${HostPoolName}'
  dependsOn: [
    joinToDomain
  ]
  params: {
    index: i+currentInstances+1
    hostPoolName: HostPoolName
    location: location
    rdshPrefix: rdshprefix
    hostPoolToken: keyvault.getSecret('${HostPoolName}')
  }
}]

/* Enable and Configure Microsoft Malware */ 

module installMalware 'extensions/install-endpointForServers.bicep' = [for i in range(0, instance_count): {
  name: 'Install-MalwareExtension-to-SessionHost${i+currentInstances+1}-in-${HostPoolName}'
  dependsOn:[
    configureFsLogix
  ]
  params: {
    index: i+currentInstances+1
    ExclusionsExtensions: '*.vhd;*.vhdx'
    ExclusionsPaths: '"%ProgramFiles%\\FSLogix\\Apps\\frxdrv.sys;%ProgramFiles%\\FSLogix\\Apps\\frxccd.sys;%ProgramFiles%\\FSLogix\\Apps\\frxdrvvt.sys;%TEMP%\\*.VHD;%TEMP%\\*.VHDX;%Windir%\\TEMP\\*.VHD;%Windir%\\TEMP\\*.VHDX;\\\\server\\share\\*\\*.VHD;\\\\server\\share\\*\\*.VHDX'
    ExclusionsProcesses: '%ProgramFiles%\\FSLogix\\Apps\\frxccd.exe;%ProgramFiles%\\FSLogix\\Apps\\frxccds.exe;%ProgramFiles%\\FSLogix\\Apps\\frxsvc.exe'
    location: location
    rdshPrefix: rdshprefix
    RealtimeProtectionEnabled: 'true'
    ScheduledScanSettingsDay: '7' // Day of the week for scheduled scan (1-Sunday, 2-Monday, ..., 7-Saturday)
    ScheduledScanSettingsIsEnabled: 'true' // Indicates whether or not custom scheduled scan settings are enabled (default is false)
    ScheduledScanSettingsScanType: 'Quick' //Indicates whether scheduled scan setting type is set to Quick or Full (default is Quick)
    ScheduledScanSettingsTime: '120'    // When to perform the scheduled scan, measured in minutes from midnight (0-1440). For example: 0 = 12AM, 60 = 1AM, 120 = 2AM.
  }
}]

