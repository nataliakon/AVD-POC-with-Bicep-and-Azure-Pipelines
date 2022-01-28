param HostPoolName string 
param location string 
@description('Key/Value pair of tags.')
param tags object = {}


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

// @allowed([
//   'BreadthFirst'
//   'DepthFirst'
//   'Persistent'
// ])
param loadBalancerType string = 'DepthFirst'

@description('The max session limit of HostPool')
param maxSessionLimit int = 12

@description('Custom RDP properties to be applied to the AVD Host Pool.')
param customRdpProperty string = ''

// @allowed([
//   'Desktop'
//   'None'
//   'RailApplications'
// ])
@description('The type of preferred application group type, default to Desktop Application Group')
param preferredAppGroupType string= 'Desktop'

param LGAworkspaceId string

resource pod_hostpool 'Microsoft.DesktopVirtualization/hostPools@2021-09-03-preview' = {
  name: HostPoolName
  location: location
  tags: tags 
  properties: {
    description: HostPoolName
    friendlyName: HostPoolName
    hostPoolType: HostPoolType
    loadBalancerType: loadBalancerType
    preferredAppGroupType: preferredAppGroupType
    maxSessionLimit: maxSessionLimit
    personalDesktopAssignmentType: PersonalDesktopAssignment
    startVMOnConnect: startVMOnConnect
    customRdpProperty: customRdpProperty
    registrationInfo: {
      expirationTime: tokenExpirationTime
      token: null
      registrationTokenOperation: 'Update'
    }
  }
}


/* Diagnostic Settings */

resource hostpool_logs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send_avd_hostpool_logs'
  scope: pod_hostpool
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

//output registratioToken string = any(pod_hostpool.properties.registrationInfo.token)
output hostpoolID string = pod_hostpool.id
