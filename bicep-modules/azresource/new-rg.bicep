targetScope = 'subscription'

param resourceGroupName string
param resourceGroupLocation string

resource newResourceGroupName 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: resourceGroupLocation
}
