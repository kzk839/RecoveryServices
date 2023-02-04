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

// @description('The DNS prefix for the public IP address used by the Load Balancer')
// param dnsPrefix string

@description('Size of the VM for the controller')
param vmSize string = 'Standard_D2s_v5'

@description('The location of resources such as templates and DSC modules that the script is dependent')
param _artifactsLocation string = 'https://raw.githubusercontent.com/daveRendon/azure-quickstart-templates/master/application-workloads/active-directory/active-directory-new-domain-ha-2-dc-zones/'

@description('Auto-generated token to access _artifactsLocation')
@secure()
param artifactsLocationSasToken string = ''

var imagePublisher = 'MicrosoftWindowsServer'
var imageOffer = 'WindowsServer'
var imageSKU = '2019-Datacenter'
var virtualNetworkName = '${resourceNamePrefix}-VNET'
var virtualNetworkAddressRange = '10.0.0.0/16'
var vmSubnetName = 'Subnet'
var vmSubnet = '10.0.0.0/24'
var vmSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, vmSubnetName)
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnet = '10.0.1.0/24'
var bastionSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, bastionSubnetName)
// var publicIPSKU = 'Standard'
var publicIpName = '${resourceNamePrefix}-bastion-ip'
var bastionHostName = '${resourceNamePrefix}-bastion'
// var publicIPAddressType = 'Static'
// var publicIpAddressId = {
//   id: publicIPAddressName.id
// }

var vmName = '${resourceNamePrefix}-DC'
var nicName = '${resourceNamePrefix}-DC-Nic'
var ipAddressPDC = '10.0.0.4'

// var adBDCConfigurationModulesURL = uri(_artifactsLocation, 'DSC/ConfigureADBDC.ps1.zip')
// var adBDCConfigurationScript = 'ConfigureADBDC.ps1'
// var adBDCConfigurationFunction = 'ConfigureADBDC'

// resource publicIPAddressName 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
//   name: publicIPAddressName_var
//   location: location
//   sku: {
//     name: publicIPSKU
//   }
//   zones: [
//     '1'
//   ]
//   properties: {
//     publicIPAllocationMethod: publicIPAddressType
//     dnsSettings: {
//       domainNameLabel: dnsPrefix
//     }
//   }
// }

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
          // publicIPAddress: ((i == 0) ? publicIpAddressId : json('null'))
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

resource CreatePDC 'Microsoft.Compute/virtualMachines@2022-11-01' = {
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

resource CreateAdForest 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: '${vmName}/CreateAdForest'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.24'
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
  dependsOn: [
    CreatePDC
  ]
}

// resource vmName_1_PepareBDC 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
//   name: '${vmName[1]}/PepareBDC'
//   location: location
//   properties: {
//     publisher: 'Microsoft.Powershell'
//     type: 'DSC'
//     typeHandlerVersion: '2.24'
//     autoUpgradeMinorVersion: true
//     settings: {
//       configuration: {
//         url: uri(_artifactsLocation, 'DSC/PrepareADBDC.ps1.zip')
//         script: 'PrepareADBDC.ps1'
//         function: 'PrepareADBDC'
//       }
//       configurationArguments: {
//         DNSServer: ipAddress[0]
//       }
//     }
//     protectedSettings: {
//       configurationUrlSasToken: artifactsLocationSasToken
//     }
//   }
//   dependsOn: [
//     vmName
//   ]
// }

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
    // vmName_1_PepareBDC
  ]
}

// module UpdateBDCNIC './nestedtemplates/nic.bicep' = {
//   name: 'UpdateBDCNIC'
//   params: {
//     nicName: nicName[1]
//     ipConfigurations: [
//       {
//         name: 'ipconfig1'
//         properties: {
//           privateIPAllocationMethod: 'Static'
//           privateIPAddress: ipAddress[1]
//           subnet: {
//             id: SubnetRef
//           }
//         }
//       }
//     ]
//     dnsServers: [
//       ipAddress[0]
//     ]
//     location: location
//   }
//   dependsOn: [
//     UpdateVNetDNS1
//   ]
// }

// module ConfiguringBackupADDomainController './nestedtemplates/configureADBDC.bicep'  = {
//   name: 'ConfiguringBackupADDomainController'
//   params: {
//     extName: '${vmName[1]}/PepareBDC'
//     location: location
//     adminUsername: adminUsername
//     adminPassword: adminPassword
//     domainName: domainName
//     adBDCConfigurationScript: adBDCConfigurationScript
//     adBDCConfigurationFunction: adBDCConfigurationFunction
//     adBDCConfigurationModulesURL: adBDCConfigurationModulesURL
//     artifactsLocationSasToken: artifactsLocationSasToken
//   }
//   dependsOn: [
//     UpdateBDCNIC
//   ]
// }

// module UpdateVNetDNS2 './nestedtemplates/vnet.bicep' = {
//   name: 'UpdateVNetDNS2'
//   params: {
//     virtualNetworkName: virtualNetworkName
//     virtualNetworkAddressRange: virtualNetworkAddressRange
//     subnetName: SubnetName
//     subnetRange: Subnet
//     DNSServerAddress: ipAddress
//     location: location
//   }
//   dependsOn: [
//     ConfiguringBackupADDomainController
//   ]
// }
