$ErrorActionPreference = "Stop"

Write-Host "Running post-provision script..." -ForegroundColor Yellow

$outputJson = azd env get-values --output json
if ($LASTEXITCODE -ne 0) {
    throw "Failed to read values from the azd environment."
}
try {
    $outputs = $outputJson | ConvertFrom-Json
}
catch {
    throw "azd returned invalid environment JSON."
}
$ServiceBusNamespace = $outputs.SERVICE_BUS_CONNECTION__fullyQualifiedNamespace
$ServiceBusQueueName = $outputs.SERVICE_BUS_QUEUE_NAME
$SubscriptionId = $outputs.AZURE_SUBSCRIPTION_ID

if ([string]::IsNullOrWhiteSpace($ServiceBusNamespace) -or
    [string]::IsNullOrWhiteSpace($ServiceBusQueueName) -or
    [string]::IsNullOrWhiteSpace($SubscriptionId)) {
    throw "SERVICE_BUS_CONNECTION__fullyQualifiedNamespace, SERVICE_BUS_QUEUE_NAME and AZURE_SUBSCRIPTION_ID are required in the azd environment."
}
if ($ServiceBusNamespace -notmatch '^[a-zA-Z0-9-]+\.servicebus\.windows\.net$' -or
    $ServiceBusQueueName -notmatch '^[a-zA-Z0-9._/-]+$' -or
    $SubscriptionId -notmatch '^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$') {
    throw "The azd environment contains an invalid Service Bus namespace, queue name or subscription ID."
}

$settingsPath = Join-Path "src" "local.settings.json"
if (Test-Path $settingsPath) {
    Write-Warning "src/local.settings.json already exists and was not changed or validated. Review these values under Values to use the provisioned resources:"
    Write-Host "  ServiceBusConnection__fullyQualifiedNamespace = $ServiceBusNamespace"
    Write-Host "  ServiceBusQueueName = $ServiceBusQueueName"
}
else {
    [ordered]@{
        "IsEncrypted" = $false
        "Values" = [ordered]@{
            "AzureWebJobsStorage" = "UseDevelopmentStorage=true"
            "FUNCTIONS_WORKER_RUNTIME" = "java"
            "ServiceBusConnection__fullyQualifiedNamespace" = $ServiceBusNamespace
            "ServiceBusQueueName" = $ServiceBusQueueName
        }
    } | ConvertTo-Json | Out-File -FilePath $settingsPath -Encoding utf8
    Write-Host "src/local.settings.json has been created successfully!" -ForegroundColor Green
}

Write-Host "Creating/updating send-message.ps1..." -ForegroundColor Yellow

@"
az rest --subscription '$SubscriptionId' --method POST --uri 'https://$ServiceBusNamespace/$ServiceBusQueueName/messages' --headers 'Content-Type=application/atom+xml;type=entry;charset=utf-8' --body 'Hello from the CLI' --resource 'https://servicebus.azure.net'
exit `$LASTEXITCODE
"@ | Out-File -FilePath ".\send-message.ps1" -Encoding utf8 -Force

Write-Host "send-message.ps1 has been created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Service Bus Namespace: $ServiceBusNamespace" -ForegroundColor Cyan
Write-Host "Service Bus Queue: $ServiceBusQueueName" -ForegroundColor Cyan
Write-Host ""
Write-Host "With VNet enabled, local use requires private endpoint connectivity and DNS." -ForegroundColor Yellow
Write-Host "You can now run the function locally with 'cd src && mvn clean package azure-functions:run'" -ForegroundColor Green
Write-Host "Send test messages with './send-message.ps1'" -ForegroundColor Green