@description('Persona name')
param persona string

@description('Pod ID') 
param pod string

@description('Key/Value pair of tags.')
param tags object = {}

/* Parameters for the workspace */

@allowed([
  'eastus'
  'westus'
  'westeurope'
  'northeurope'
  'uksouth'
])
param workspaceLocation string = 'eastus'
//param workspaceName string = '${persona}-Workspace'

/* paramaters for Host pool */

param HostPoolName string = '${persona}-${pod}-Pool'

param basetime string = utcNow('d')
@description('Expiration time for the HostPool registration token. This must be up to 30 days from todays date.')
param tokenExpirationTime string = dateTimeAdd(basetime,'P7D')

@allowed([
  'Personal'
  'Pooled'
  'BYODesktop'
])
param HostPoolType string = 'Pooled'

@allowed([
  'Automatic'
  'Direct'
])

param PersonalDesktopAssignment string = 'Automatic'

@description('Enable feature to start the session hosts as users connect')
param startVMOnConnect bool = true

@allowed([
  'BreadthFirst'
  'DepthFirst'
  'Persistent'
])
param loadBalancerType string = 'DepthFirst'

@description('The max session limit of HostPool')
param maxSessionLimit int = 12

@description('Custom RDP properties to be applied to the AVD Host Pool.')
param customRdpProperty string = ''

/* paramaters for Application group */

@allowed([
  'Desktop'
  'None'
  'RailApplications'
])
@description('The type of preferred application group type, default to Desktop Application Group')
param preferredAppGroupType string= 'Desktop'

param appGroupName string = '${persona}-${pod}-AppGroup'

param LGAworkspaceId string

// ===================================================================================== // 

// ====================================================================================== //

/* Create Host Pool */

module hostpool 'avd/host-pool.bicep' = {
  name: 'Deploy-hostpool-${HostPoolName}'
  params: { 
    HostPoolName: HostPoolName
    location: workspaceLocation
    tags: tags
    HostPoolType: HostPoolType
    tokenExpirationTime: tokenExpirationTime
    PersonalDesktopAssignment: PersonalDesktopAssignment
    preferredAppGroupType: preferredAppGroupType
    loadBalancerType: loadBalancerType
    maxSessionLimit: maxSessionLimit
    customRdpProperty: customRdpProperty
    startVMOnConnect: startVMOnConnect
    LGAworkspaceId: LGAworkspaceId
  }
}


/* Create Application Group. */
module appgroup 'avd/application-group.bicep' = {
  name: 'Deploy-appgroup-${appGroupName}'
  params: {
    tags: tags
    location: workspaceLocation
    appGroupName: appGroupName
    appGroupFriendlyName: appGroupName
    appGroupType: preferredAppGroupType
    appGroupDescription: appGroupName
    hostpoolResourceID: hostpool.outputs.hostpoolID
    LGAworkspaceId: LGAworkspaceId
  }
  dependsOn: [
    hostpool
  ]
}


output appgroupID string = appgroup.outputs.appGroupResourceID
output hostpoolID string = hostpool.outputs.hostpoolID

// // /* Call on the workspace to get the list of existing Application groups. */

// resource existingworkspace 'Microsoft.DesktopVirtualization/workspaces@2021-09-03-preview' existing = {
//   name: workspaceName
// }

// /* Update the workspace */

// module workspace 'avd/update-workspace.bicep' = {
//   name: 'Update-AVD-Workspace-${workspaceName}'
//   params: {
//     workspaceLocation: workspaceLocation
//     workspaceName: workspaceName
//     workspaceFriendlyName: existingworkspace.properties.friendlyName
//     workspaceDescription: existingworkspace.properties.description
//     existingApplicationGroupReferences: existingworkspace.properties.applicationGroupReferences
//     newApplicationGroupReference: appgroup.outputs.appGroupResourceID
//  }
//  dependsOn: [
//    appgroup
//  ]
// }
