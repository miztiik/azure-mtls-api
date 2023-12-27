// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2023-12-23'
  owner: 'miztiik@github'
}

param deploymentParams object
param tags object
param logAnalyticsWorkspaceId string
param enableDiagnostics bool = true

param fn_app_name string
param app_insights_name string

@description('Get App Insights Workspace Id')
resource r_app_insights_Ref 'Microsoft.Insights/components@2020-02-02' existing = {
  name: app_insights_name
}

resource r_fn_app_Ref 'Microsoft.Web/sites@2022-03-01' existing = {
  name: fn_app_name
}

@description('Create API Management Service')
// var __apim_name = replace('${deploymentParams.enterprise_name_suffix}-${fn_params.app_name_prefix}-${deploymentParams.loc_short_code}-apim-${deploymentParams.global_uniqueness}', '_', '-')
var __apim_name = replace('${deploymentParams.enterprise_name_suffix}-store-front-${deploymentParams.loc_short_code}-apim-${deploymentParams.global_uniqueness}', '_', '-')

resource r_apim_1 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: __apim_name
  location: deploymentParams.location
  tags: tags
  sku: {
    name: 'Basic' // Developer, Basic, Standard, Premium, Consumption
    capacity: 1 // has to be 0 for Consumption tier
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: 'Miztiik@github'
    publisherName: 'Mystique Corp'
    publicNetworkAccess: 'Enabled'
    // certificates:
  }
}

@description('Create logger for APIM')
resource r_apim_1_logger 'Microsoft.ApiManagement/service/loggers@2022-09-01-preview' = {
  name: '${__apim_name}_logger'
  parent: r_apim_1
  properties: {
    loggerType: 'applicationInsights'
    resourceId: r_app_insights_Ref.id
    credentials: {
      instrumentationKey: r_app_insights_Ref.properties.InstrumentationKey
    }
    description: 'Application Insights telemetry from APIs'
  }
}

@description('Create Named Values for APIM')
resource r_apim_1_named_value_apim_name 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  name: 'API_M_NAME'
  parent: r_apim_1
  properties: {
    displayName: 'API_M_NAME'
    secret: false
    value: r_apim_1.name
  }
}

@description('Create Sample Policy for APIM')
var __apim_policy_str = '<!--\r\n    MIZTIIK SAYS IT IS IMPORTANT:\r\n    - Policy elements can appear only within the <inbound>, <outbound>, <backend> section elements.\r\n    - Only the <forward-request> policy element can appear within the <backend> section element.\r\n    - To apply a policy to the incoming request (before it is forwarded to the backend service), place a corresponding policy element within the <inbound> section element.\r\n    - To apply a policy to the outgoing response (before it is sent back to the caller), place a corresponding policy element within the <outbound> section element.\r\n    - To add a policy position the cursor at the desired insertion point and click on the round button associated with the policy.\r\n    - To remove a policy, delete the corresponding policy statement from the policy document.\r\n    - Policies are applied in the order of their appearance, from the top down.\r\n-->\r\n<policies>\r\n  <inbound></inbound>\r\n  <backend>\r\n    <forward-request />\r\n  </backend>\r\n  <outbound></outbound>\r\n</policies>'
resource r_apim_1_policy 'Microsoft.ApiManagement/service/policies@2021-08-01' = {
  name: 'policy'
  parent: r_apim_1
  properties: {
    format: 'xml'
    value: __apim_policy_str
  }
}

////////////////////////////////////////////
//                                        //
//        BACKEND DEFINITION              //
//                                        //
////////////////////////////////////////////

@description('Create Named Values for Function Key')
resource r_apim_1_named_value_fn_key 'Microsoft.ApiManagement/service/namedValues@2021-12-01-preview' = {
  parent: r_apim_1
  name: 'fn-api-key'
  properties: {
    displayName: 'fn-api-key'
    secret: true
    value: listkeys('${r_fn_app_Ref.id}/host/default', '2016-08-01').functionKeys.default
    tags: [
      'miztiik_automation'
      'key'
      'function'
      'auto'
    ]
  }
}

var __bckend_name = 'generate-events'

resource r_apim_1_backend_event_generator 'Microsoft.ApiManagement/service/backends@2021-12-01-preview' = {
  parent: r_apim_1
  name: __bckend_name
  properties: {
    title: 'WHERE DOES THE TITLE GO?' // Shows up in the resource blade
    description: 'Azure Function that generates store event(s) and send it to the service bus topic'
    // url: 'https://${r_fn_app_Ref.name}.azurewebsites.net'
    url: 'https://${r_fn_app_Ref.properties.hostNames[0]}'
    protocol: 'http'
    resourceId: '${environment().resourceManager}${r_fn_app_Ref.id}'
    credentials: {
      query: {}
      header: {
        'x-functions-key': [
          '{{${r_apim_1_named_value_fn_key.name}}}'
        ]
      }
    }

    tls: {
      validateCertificateChain: false
      validateCertificateName: false
    }
  }
}

////////////////////////////////////////////
//                                        //
//            API DEFINITION              //
//                                        //
////////////////////////////////////////////

@description('Resource definition for API within Azure API Management')
resource r_apim_1_apis 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: r_apim_1
  name: 'store-events-api'
  properties: {
    displayName: 'Store Events API'
    path: 'api'
    description: 'API for miztiik store front'
    protocols: [
      'https'
    ]
    isCurrent: true
    // apiRevision: '1'
    // apiVersion: '1'
    // subscriptionKeyParameterNames: {
    //   header: 'Ocp-Apim-Subscription-Key'
    //   query: 'subscription-key'
    // }
    subscriptionRequired: false
  }
}

@description('Resource definition for an "event generation" operation within the API')
resource r_apim_1_apis_get_event 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: r_apim_1_apis
  name: 'generate-events'
  properties: {
    displayName: 'Generate Store Event'
    method: 'GET'
    urlTemplate: '/store-events-producer-fn' //HARD CODED FOR NOW - TODO: FIX THIS // As my functionapp has two functions getting the name is going to be hard.
    request: {
      description: 'Generate store event(s) and send it to the service bus topic'
      queryParameters: [
        // {
        //   name: 'filter'
        //   type: 'string'
        //   required: false
        // }
      ]
      headers: [] // Empty headers - No API Key Required
    }
    responses: [
      // {
      //   statusCode: 200
      //   description: 'Store Event Generated Successfully'
      // }
      // {
      //   description: 'not authorized'
      //   statusCode: 401
      // }
    ]
  }
}

var __policy_content = loadTextContent('api_policies/fn_backend_policy.xml', 'utf-8')
var __fn_backend_policy = replace(__policy_content, '__BACKEND-ID__', '${r_apim_1_backend_event_generator.name}')
resource getOrdersPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2021-12-01-preview' = {
  name: 'policy'
  parent: r_apim_1_apis_get_event
  properties: {
    // value: replace(replace(loadTextContent('apimPolicies/operation.xml'), '{method}', 'GET'), '{template}', '/orders/{storeId}')
    value: __fn_backend_policy
    format: 'xml'
  }
}

@description('Create general purpose logger for APIs')
resource r_apim_1_apis_logger 'Microsoft.ApiManagement/service/apis/diagnostics@2022-09-01-preview' = {
  name: 'applicationinsights' //TODO: Apparently this is a reserved name.
  parent: r_apim_1_apis
  properties: {
    alwaysLog: 'allErrors'
    logClientIp: true
    metrics: true
    httpCorrelationProtocol: 'W3C'
    verbosity: 'error'
    loggerId: r_apim_1_logger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    backend: {
      response: {
        body: {
          bytes: 1024
        }
      }
    }
  }
}

////////////////////////////////////////////
//                                        //
//         Diagnostic Settings            //
//                                        //
////////////////////////////////////////////

@description('Diagnostic Settings for APIM')
resource r_apim_svc_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: '${__apim_name}-diags'
  scope: r_apim_1
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
      // {
      //   categoryGroup: 'audit'
      //   enabled: true
      // }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
  }
}

// OUTPUTS
output module_metadata object = module_metadata

//APIM Outputs
output apim_name string = r_apim_1.name
output fn_name_tst string = r_fn_app_Ref.properties.usageState
output svc_url string = '${r_apim_1.properties.gatewayUrl}/api/generate-events'
