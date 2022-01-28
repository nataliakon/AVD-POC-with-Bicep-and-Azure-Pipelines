param currentInstances int 
param instance_count int
param rdshPrefix string
param location string

resource microsoftdenfender 'Microsoft.Compute/virtualMachines/providers/serverVulnerabilityAssessments@2015-06-01-preview' = [ for i in range(0,instance_count):{
  name: '${rdshPrefix}vm${i+currentInstances}/Microsoft.Security/MdeTvm'
  location: location
}]
