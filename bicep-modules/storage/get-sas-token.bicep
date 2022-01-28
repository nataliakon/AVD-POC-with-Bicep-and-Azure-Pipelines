@description('The base URI where artifacts required by this template are located including a trailing \'/\'')
param storageaccountName string
param container string

@description('Resource group of the storage account for customizer script')

param storageaccountRG string

param baseTime string = utcNow('u')

//var endtime_add1hour = dateTimeAdd(baseTime, 'PT1H')

param accountSasProperties object  = {
  signedProtocol: 'https'
  signedResourceTypes: 'sco'
  signedPermission: 'rl'
  signedServices: 'b'
  signedExpiry: dateTimeAdd(baseTime, 'PT1H')
}

param myContainerUploadSasProperties object = {
   canonicalizedResource: '/blob/${storageaccountName}/${container}'
   signedResource: 'c'
   signedProtocol: 'https'
   signedPermission: 'rl'
   signedServices: 'b'
   signedExpiry: dateTimeAdd(baseTime, 'PT1H')
}

resource stg 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageaccountName
  scope: resourceGroup(storageaccountRG)
}

output blobEndpoint string = stg.properties.primaryEndpoints.blob
output ContainerBlobEndpoint string = '${stg.properties.primaryEndpoints.blob}${container}'
output stgID string = stg.id

//SAS to download all blobs in account

output allBlobDownloadSAS string = stg.listAccountSas ('2021-04-01', accountSasProperties).accountSasToken


//SAS to upload blobs to just the mycontainer container.

output myContainerUploadSAS string = stg.listServiceSas ('2021-04-01',myContainerUploadSasProperties).serviceSasToken
