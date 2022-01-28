param index int 
param rdshPrefix string
param vmSize string
param storageAccountType string
param location string = resourceGroup().location
@description('Key/Value pair of tags.')
param tags object = {}

param VnetName string
param VnetResourceGroup string
param subnetName string

@secure()
param adminUsername string 
@secure()
param adminPassword string

param useSharedImage bool
param shared_image_gallery_rg string 
param shared_image_gallery_name string 
param shared_image_gallery_definition string

@description('Gallery image version to be used if SIG is not used')
param image string = 'Windows10'

@description('Timezone to be set on the VMs')
param timezone string 

param zones array

@description('The flag that enables or disables hibernation capability on the VM')
param hibernationEnabled bool

// @description(' enable or disable the Host Encryption for the virtual machine or virtual machine scale set. This will enable the encryption for all the disks including Resource/Temp disk at host itself.')
// param encryptionAtHost bool

// ============================================= // 

var marketPlaceGalleyWindows10 = {

Windows10: {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-10'
  sku: '21h1-evd'
  version: 'latest'
}

Windows10withO365: {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'office-365'
  sku: '21h1-evd'
  version: 'latest'
}

  }


// ============================================= // 


/* Get the the subnet */

resource subnet 'Microsoft.Network/virtualnetworks/subnets@2015-06-15' existing = {
  name: '${VnetName}/${subnetName}'
  scope: resourceGroup(VnetResourceGroup)
}


/* Provision NICs */

resource NICs 'Microsoft.Network/networkInterfaces@2021-03-01' =  {
  name: '${rdshPrefix}NIC${index}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
    enableIPForwarding: false
  }
}

/* Get resource ID of the custom image published in Azure Compute Gallery */

resource sigImage 'Microsoft.Compute/galleries/images@2021-07-01' existing = if (useSharedImage){
  name: '${shared_image_gallery_name}/${shared_image_gallery_definition}'
  scope: resourceGroup(shared_image_gallery_rg)
}

output imageId string = sigImage.id

/* Provision VMs*/

resource VMs 'Microsoft.Compute/virtualMachines@2021-07-01'= {
  name: '${rdshPrefix}vm${index}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  zones: zones
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: NICs.id
        }
      ]
    }
    storageProfile: {
      imageReference: useSharedImage ? '"id" : ${sigImage.id} ' : marketPlaceGalleyWindows10[image]
      osDisk: {
        name: '${rdshPrefix}${index}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
        }
        caching: 'ReadWrite'
      }
    }
    osProfile: {
      computerName: '${rdshPrefix}vm${index}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent:true
        timeZone: timezone
      }
    }
    licenseType: 'Windows_Client'
    
    additionalCapabilities: {
      hibernationEnabled: hibernationEnabled 
    }

    // securityProfile: {
    //   encryptionAtHost: encryptionAtHost
    // }

  }
}


