// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2023-12-25'
  owner: 'miztiik@github'
}

param deploymentParams object
param vnet_params object

param tags object = resourceGroup().tags

param vnet_address_prefixes object = {
  addressPrefixes: [
    '10.0.0.0/16'
  ]
}
param web_subnet_01_cidr string = '10.0.0.0/24'
param web_subnet_02_cidr string = '10.0.1.0/24'
param app_subnet_01_cidr string = '10.0.2.0/24'
param app_subnet_02_cidr string = '10.0.3.0/24'
param db_subnet_01_cidr string = '10.0.4.0/24'
param db_subnet_02_cidr string = '10.0.5.0/24'

/*
param flex_db_subnet_cidr string = '10.0.6.0/24'
param dbSubnet02Cidr string = '10.0.7.0/24'
param dbSubnet02Cidr string = '10.0.8.0/24'
*/

param pvt_endpoint_subnet_cidr string = '10.0.10.0/24'

param gateway_subnet_cidr string = '10.0.20.0/24'
param fw_subnet_cidr string = '10.0.30.0/24'

param k8s_subnet_cidr string = '10.0.128.0/19'
// param k8s_service_cidr string = '10.0.191.0/24' // Do not change this

@description('Create a VNET with subnets')
var __vnet_name = replace('${deploymentParams.enterprise_name_suffix}-${deploymentParams.loc_short_code}-${vnet_params.name_prefix}-vnet-${deploymentParams.global_uniqueness}', '_', '-')

resource r_vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: __vnet_name
  location: deploymentParams.location
  tags: tags
  properties: {
    addressSpace: vnet_address_prefixes
    subnets: [
      {
        name: 'web_subnet_01'
        properties: {
          addressPrefix: web_subnet_01_cidr
        }
      }
      {
        name: 'web_subnet_02'
        properties: {
          addressPrefix: web_subnet_02_cidr
        }
      }
      {
        name: 'app_subnet_01'
        properties: {
          addressPrefix: app_subnet_01_cidr
        }
      }
      {
        name: 'app_subnet_02'
        properties: {
          addressPrefix: app_subnet_02_cidr
        }
      }
      {
        name: 'db_subnet_01'
        properties: {
          addressPrefix: db_subnet_01_cidr
        }
      }
      {
        name: 'db_subnet_02'
        properties: {
          addressPrefix: db_subnet_02_cidr
        }
      }
      {
        name: 'pvt_endpoint_subnet'
        properties: {
          addressPrefix: pvt_endpoint_subnet_cidr
        }
      }
      {
        name: 'k8s_subnet'
        properties: {
          addressPrefix: k8s_subnet_cidr
        }
      }
      {
        name: 'gw_subnet'
        properties: {
          addressPrefix: gateway_subnet_cidr
        }
      }
      {
        name: 'fw_subnet'
        properties: {
          addressPrefix: fw_subnet_cidr
        }
      }
    ]
  }
}

// resource ng 'Microsoft.Network/natGateways@2021-03-01' = if (nat_gateway) {
//   name: 'ng-${name}'
//   location: deploymentParams.location
//   tags: tags
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     idleTimeoutInMinutes: 4
//     publicIpAddresses: [
//       {
//         id: pip.id
//       }
//     ]
//   }
// }

// resource pip 'Microsoft.Network/publicIPAddresses@2021-03-01' = if (natGateway) {
//   name: 'pip-ng-${name}'
//   location: deploymentParams.location
//   tags: tags
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     publicIPAllocationMethod: 'Static'
//   }
// }

// OUTPUTS
output module_metadata object = module_metadata

output vnetId string = r_vnet.id
output vnet_name string = r_vnet.name
output vnet_subnets array = r_vnet.properties.subnets

output web_subnet_01_name string = r_vnet.properties.subnets[0].name

output db_subnet_01_id string = r_vnet.properties.subnets[4].id
output db_subnet_02_id string = r_vnet.properties.subnets[5].id

output pvt_endpoint_subnet string = r_vnet.properties.subnets[6].id
