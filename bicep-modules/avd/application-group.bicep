@description('Key/Value pair of tags.')
param tags object = {}
param appGroupName string
param location string
param appGroupFriendlyName string
param appGroupType string
param appGroupDescription string
param hostpoolResourceID string
param LGAworkspaceId string

resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2019-12-10-preview' =  {
  name: appGroupName
  tags: tags
  location: location
  properties: {
    friendlyName: appGroupFriendlyName
    applicationGroupType: appGroupType
    description: appGroupDescription
    hostPoolArmPath: hostpoolResourceID
  }
}

/* Diagnostic Settings */

resource appgroup_logs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send_avd_appgroup_logs'
  scope: applicationGroup
  properties: {
    workspaceId: LGAworkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

output appGroupResourceID string = applicationGroup.id
