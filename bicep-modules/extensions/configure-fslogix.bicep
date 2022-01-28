param rdshPrefix string 
param location string 
param shareName string 
param index int 


@description('The base URI where artifacts required by this template are located including a trailing \'/\'')
param storageaccountName string
param container string

@description('Resource group of the storage account for customizer script')

param storageaccountRG string

var FSLogixScriptFolder = '.'
var FsLogixScript = 'Set-FSLogixRegKeys.ps1'
var FsLogixScriptName = '/s/scripts/Set-FSLogixRegKeys.ps1'
var FsLogixScriptArguments = '-volumeshare ${shareName}'
var FsLogixScriptUri = '${storage.properties.primaryEndpoints.blob}${container}${FsLogixScriptName}'

// Get the storage account 

resource storage 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageaccountName
  scope: resourceGroup(storageaccountRG)
}


// Run Custom extension to configure FSlogix
resource fslogixconfigure 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  name: '${rdshPrefix}vm${index}/configurefslogix'
  location: location
  properties: {
    publisher:'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings:{}
    protectedSettings: {
      storageAccountName: storageaccountName
      storageAccountKey: storage.listKeys().keys[0].value
      fileUris: array(FsLogixScriptUri)
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ${FSLogixScriptFolder}${FsLogixScriptName} ${FsLogixScriptArguments}'
    }

  }
  
}
