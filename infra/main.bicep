targetScope = 'resourceGroup'

@description('Resource name prefix. Use lowercase letters and numbers only.')
@minLength(2)
@maxLength(8)
param namePrefix string = 'smk'

@description('Environment name such as dev, test, or prod.')
@minLength(2)
@maxLength(8)
param environmentName string

@description('Azure region for regional resources.')
param location string = resourceGroup().location

@description('Foundry project endpoint. Leave empty until the project is provisioned and verified.')
param foundryProjectEndpoint string = ''

@description('Foundry model deployment name. Leave empty to use the local development research provider.')
param foundryModelDeployment string = ''

@description('Enable the Foundry research provider. If enabled, endpoint, model deployment, and managed identity must be configured.')
param enableFoundryResearch bool = false

@description('Microsoft Learn MCP endpoint. The backend currently allows only the verified official endpoint.')
param learnMcpUrl string = 'https://learn.microsoft.com/api/mcp'

@description('Agent name prefix used to create short-lived Foundry agents.')
@minLength(1)
@maxLength(20)
param foundryAgentNamePrefix string = 'shirabete'

@description('App Service plan SKU. Review regional availability and production capacity before deployment.')
@allowed([
  'B1'
  'B2'
  'B3'
  'P0v3'
  'P1v3'
  'P2v3'
  'P3v3'
])
param appServicePlanSku string = 'P1v3'

@description('App Service Java runtime stack. Verify the selected runtime is supported in the target region.')
param javaRuntime string = 'JAVA|25-java25'

@description('Azure AI Search SKU. Standard is used for production-oriented features.')
param searchSku string = 'standard'

var suffix = uniqueString(subscription().id, resourceGroup().id)
var appServicePlanTier = startsWith(appServicePlanSku, 'P') ? 'PremiumV3' : 'Basic'
var apiName = '${namePrefix}-${environmentName}-api-${suffix}'
var staticWebAppName = '${namePrefix}-${environmentName}-web-${suffix}'
var storageName = toLower('smk${take(namePrefix, 4)}${take(environmentName, 4)}${take(suffix, 13)}')
var searchName = '${namePrefix}-${environmentName}-search-${suffix}'
var vaultName = take('${namePrefix}-${environmentName}-kv-${suffix}', 24)
var appInsightsName = '${namePrefix}-${environmentName}-appi-${suffix}'
var logAnalyticsName = '${namePrefix}-${environmentName}-logs-${suffix}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: logAnalytics.id
    DisableIpMasking: false
  }
}

resource apiPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${namePrefix}-${environmentName}-plan'
  location: location
  kind: 'linux'
  sku: {
    name: appServicePlanSku
    tier: appServicePlanTier
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

resource api 'Microsoft.Web/sites@2023-12-01' = {
  name: apiName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: apiPlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: javaRuntime
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      healthCheckPath: '/api/health'
      appCommandLine: ''
    }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource reportsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'reports'
  properties: {
    publicAccess: 'None'
  }
}

resource search 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchName
  location: location
  sku: {
    name: searchSku
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
    semanticSearch: 'free'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    disableLocalAuth: true
  }
}

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource apiSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: api
  name: 'appsettings'
  properties: {
    RESEARCH_MODE: enableFoundryResearch ? 'foundry' : 'local'
    STORAGE_MODE: 'local'
    SEARCH_MODE: 'local'
    REPORT_STORAGE_DIRECTORY: '/home/data/reports'
    CORS_ALLOWED_ORIGINS: 'https://${staticWebApp.properties.defaultHostname}'
    FOUNDRY_PROJECT_ENDPOINT: foundryProjectEndpoint
    FOUNDRY_MODEL_DEPLOYMENT: foundryModelDeployment
    FOUNDRY_AGENT_NAME_PREFIX: foundryAgentNamePrefix
    LEARN_MCP_URL: learnMcpUrl
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
    APPLICATIONINSIGHTS_ROLE_NAME: apiName
    WEBSITES_PORT: '8080'
    WEBSITE_ENABLE_APP_SERVICE_STORAGE: 'true'
  }
}

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: staticWebAppName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
  }
}

resource apiDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-workspace'
  scope: api
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output apiBaseUrl string = 'https://${api.properties.defaultHostName}'
output staticWebAppName string = staticWebApp.name
output staticWebAppDefaultHostname string = staticWebApp.properties.defaultHostname
output storageAccountName string = storage.name
output reportsContainerName string = reportsContainer.name
output searchServiceName string = search.name
output searchEndpoint string = 'https://${search.name}.search.windows.net'
output keyVaultName string = vault.name
output keyVaultUri string = vault.properties.vaultUri
output applicationInsightsName string = appInsights.name
output logAnalyticsWorkspaceName string = logAnalytics.name
output apiManagedIdentityPrincipalId string = api.identity.principalId
