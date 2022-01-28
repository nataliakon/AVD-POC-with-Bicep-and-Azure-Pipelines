param index int 
param rdshPrefix string
param location string


param ouPath string
param domainToJoin string
@secure()
param joinDomainAccount string
@secure()
param joinDomainPassword string



resource joinToDomain 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' =  {
  name: '${rdshPrefix}vm${index}/joinToDomain'
  location: location
  properties:{
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainToJoin
      ouPath: ouPath
      user: joinDomainAccount
      restart: 'true'
      options: '3'
             }
    protectedSettings: {
      password: joinDomainPassword
    }
  }

}
