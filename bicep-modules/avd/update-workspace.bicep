
@allowed([
  'eastus'
  'westus'
  'westeurope'
  'northeurope'
  'uksouth'
])

@description('Location for AVD resources. Can only be provisioned in the supported regions.')
param workspaceLocation string

@description('AVD workspace name. Name pattern is driven by pipeline')
param workspaceName string

param workspaceDescription string
param workspaceFriendlyName string

@description('Key/Value pair of tags.')
param tags object = {}


param existingApplicationGroupReferences array
param newApplicationGroupReference string

var appGroupResourceID = array(newApplicationGroupReference)
var applicationGroupReferencesArr = existingApplicationGroupReferences == '' ? appGroupResourceID : concat(existingApplicationGroupReferences, appGroupResourceID)

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2021-09-03-preview' = {
  name: workspaceName
  location: workspaceLocation
  tags: tags
  properties:{
    description: workspaceDescription
    friendlyName: workspaceFriendlyName
    applicationGroupReferences: applicationGroupReferencesArr
  }
}

output workspaceID string = workspace.id
output workspaceName string = workspace.name 
output workspaceAppGroups array = workspace.properties.applicationGroupReferences
