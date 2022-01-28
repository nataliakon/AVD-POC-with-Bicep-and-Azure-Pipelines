
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

param applicationGroupReferences array = []
param LGAworspaceId string

@description('Key/Value pair of tags.')
param tags object = {}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2021-09-03-preview' = {
  name: workspaceName
  location: workspaceLocation
  tags: tags
  properties:{
    description: workspaceDescription
    friendlyName: workspaceFriendlyName
    applicationGroupReferences: applicationGroupReferences
  }
}

/* Diagnostic Settings */

resource avd_logs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send_avd_workspace_logs_to_lga'
  scope: workspace
  properties: {
    workspaceId: LGAworspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

output workspaceID string = workspace.id
output workspaceName string = workspace.name 
output workspaceAppGroups array = workspace.properties.applicationGroupReferences
