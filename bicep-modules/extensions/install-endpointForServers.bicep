
param index int
param rdshPrefix string
param location string

param RealtimeProtectionEnabled string
param ScheduledScanSettingsIsEnabled string
param ScheduledScanSettingsDay string
param ScheduledScanSettingsTime string
param ScheduledScanSettingsScanType string
param ExclusionsExtensions string
param ExclusionsPaths string
param ExclusionsProcesses string

resource malwareextension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' =  {
  name: '${rdshPrefix}vm${index}/IaaSMalware'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type:'IaaSAntimalware'
    typeHandlerVersion:'1.3'
    autoUpgradeMinorVersion: true
    settings: {
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: RealtimeProtectionEnabled
      ScheduledScanSettings: {
        isEnabled: ScheduledScanSettingsIsEnabled
        day: ScheduledScanSettingsDay
        time: ScheduledScanSettingsTime
        scanType: ScheduledScanSettingsScanType
      }
      Exclusions: {
        Extensions: ExclusionsExtensions
        Paths: ExclusionsPaths
        Processes: ExclusionsProcesses
      }
    }
  }
}
