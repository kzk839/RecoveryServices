@description('Location for the VM, only certain regions support zones during preview.')
@allowed([
  'japaneast'
  'japanwest'
])
param location string

@description('The name of the Administrator of the new VM and Domain')
param adminUsername string

@description('The password for the Administrator account of the new VM and Domain')
@secure()
param adminPassword string

@description('The FQDN of the AD Domain created ')
param domainName string = 'contoso.local'

@maxLength(6)
@description('Resources Name Prefix')
param resourceNamePrefix string

@description('Size of the VM for the controller')
param vmSize string = 'Standard_D2s_v3'

@description('The location of resources such as templates and DSC modules that the script is dependent')
param _artifactsLocation string = 'https://raw.githubusercontent.com/kzk839/RecoveryServices/master/'

@description('Auto-generated token to access _artifactsLocation')
@secure()
param artifactsLocationSasToken string = ''

var imagePublisher = 'MicrosoftWindowsServer'
var imageOffer = 'WindowsServer'
var imageSKU = '2019-Datacenter'
var asrImageSKU = '2016-Datacenter'
var virtualNetworkName = '${resourceNamePrefix}-VNET'
var virtualNetworkAddressRange = '10.0.0.0/16'
var vmSubnetName = 'Subnet'
var vmSubnet = '10.0.0.0/24'
var vmSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, vmSubnetName)
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnet = '10.0.1.0/24'
var bastionSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, bastionSubnetName)
var publicIpName = '${resourceNamePrefix}-bastion-ip'
var bastionHostName = '${resourceNamePrefix}-bastion'

var storageAccountName = '${resourceNamePrefix}${uniqueString(resourceGroup().id)}'

var vmName = '${resourceNamePrefix}-DC'
var nicName = '${resourceNamePrefix}-DC-Nic'
var ipAddressPDC = '10.0.0.4'

var vmName2 = '${resourceNamePrefix}-RecVM1'
var nicName2 = '${resourceNamePrefix}-RecVM1-Nic'
var ipAddressVm2 = '10.0.0.5'
var vmSize2 = 'Standard_A2_v2'


var vmName3 = '${resourceNamePrefix}-BKSvr'
var nicName3 = '${resourceNamePrefix}-BKSvr-Nic'
var ipAddressVm3 = '10.0.0.6'
var vmSize3 = 'Standard_D2s_v3'

var vmName4 = '${resourceNamePrefix}-CSPSSvr'
var nicName4 = '${resourceNamePrefix}-CSPSSvr-Nic'
var ipAddressVm4 = '10.0.0.7'
var vmSize4 = 'Standard_D2s_v3'

var vmName5 = '${resourceNamePrefix}-Migrated'
var nicName5 = '${resourceNamePrefix}-Migrated'
var ipAddressVm5 = '10.0.0.8'
var vmSize5 = 'Standard_A2_v2'

module CreateVNet './nestedtemplates/vnet.bicep' = {
  name: 'vNet'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: vmSubnetName
    subnetRange: vmSubnet
    bastionSubnetName: bastionSubnetName
    bastionSubnetRange: bastionSubnet
    location: location
  }
}

resource publicIpAddressForBastion 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: bastionHostName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetRef
          }
          publicIPAddress: {
            id: publicIpAddressForBastion.id
          }
        }
      }
    ]
  }
  dependsOn: [
    CreateVNet
  ]
}

resource CreateStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}


resource CreateNIC 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddressPDC
          subnet: {
            id: vmSubnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    CreateVNet
  ]
}

resource CreateVM1 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSKU
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadOnly'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 64
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', nicName)
        }
      ]
    }
  }
  dependsOn: [
    CreateNIC
  ]
}

resource CreateAdForest 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: CreateVM1
  name: 'CreateAdForest'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: uri(_artifactsLocation, 'DSC/CreateADPDC.ps1.zip')
        script: 'CreateADPDC.ps1'
        function: 'CreateADPDC'
      }
      configurationArguments: {
        domainName: domainName
      }
    }
    protectedSettings: {
      configurationUrlSasToken: artifactsLocationSasToken
      configurationArguments: {
        adminCreds: {
          userName: adminUsername
          password: adminPassword
        }
      }
    }
  }
}

module UpdateVNetDNS1 './nestedtemplates/vnet.bicep' = {
  name: 'UpdateVNetDNS1'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: vmSubnetName
    subnetRange: vmSubnet
    bastionSubnetName: bastionSubnetName
    bastionSubnetRange: bastionSubnet
    DNSServerAddress: [
      ipAddressPDC
    ]
    location: location
  }
  dependsOn: [
    CreateAdForest
  ]
}

resource CreateNIC2 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nicName2
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddressVm2
          subnet: {
            id: vmSubnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    CreateVNet
  ]
}

resource CreateVM2 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName2
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize2
    }
    osProfile: {
      computerName: vmName2
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSKU
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadOnly'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 128
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', nicName2)
        }
      ]
    }
  }
  dependsOn: [
    CreateNIC2
    UpdateVNetDNS1
  ]
}

resource virtualMachineExtension1 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: CreateVM2
  name: 'joindomain1'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainName
      user: '${domainName}\\${adminUsername}'
      restart: true
      options: '3'
    }
    protectedSettings: {
      Password: adminPassword
    }
  }
}

resource CreateNIC3 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nicName3
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddressVm3
          subnet: {
            id: vmSubnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    CreateVNet
  ]
}

resource CreateVM3 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName3
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize3
    }
    osProfile: {
      computerName: vmName3
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSKU
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadOnly'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 128
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', nicName3)
        }
      ]
    }
  }
  dependsOn: [
    CreateNIC3
    UpdateVNetDNS1
  ]
}

resource virtualMachineExtension2 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: CreateVM3
  name: 'joindomain2'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainName
      // ouPath: 'OU=Computers,DC=contoso,DC=local'
      user: '${domainName}\\${adminUsername}'
      restart: true
      options: '3'
    }
    protectedSettings: {
      Password: adminPassword
    }
  }
}

resource CreateNIC4 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nicName4
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddressVm4
          subnet: {
            id: vmSubnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    CreateVNet
  ]
}

resource CreateVM4 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName4
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize4
    }
    osProfile: {
      computerName: vmName4
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: asrImageSKU
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadOnly'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', nicName4)
        }
      ]
    }
  }
  dependsOn: [
    CreateNIC4
    UpdateVNetDNS1
  ]
}

resource CreateNIC5 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nicName5
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddressVm5
          subnet: {
            id: vmSubnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    CreateVNet
  ]
}

resource CreateVM5 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName5
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize5
    }
    osProfile: {
      computerName: vmName4
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: asrImageSKU
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadOnly'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', nicName5)
        }
      ]
    }
  }
  dependsOn: [
    CreateNIC5
    UpdateVNetDNS1
  ]
}
