#!/bin/bash
set -euo pipefail

echo "Running post-provision script..."

if ! output=$(azd env get-values); then
    echo "Failed to read values from the azd environment." >&2
    exit 1
fi

ServiceBusNamespace=""
ServiceBusQueueName=""
SubscriptionId=""
while IFS= read -r line; do
    line="${line%$'\r'}"
    value="${line#*=}"
    value="${value#\"}"
    value="${value%\"}"
    if [[ $line == SERVICE_BUS_CONNECTION__fullyQualifiedNamespace=* ]]; then
        ServiceBusNamespace="$value"
    elif [[ $line == SERVICE_BUS_QUEUE_NAME=* ]]; then
        ServiceBusQueueName="$value"
    elif [[ $line == AZURE_SUBSCRIPTION_ID=* ]]; then
        SubscriptionId="$value"
    fi
done <<< "$output"

if [ -z "$ServiceBusNamespace" ] || [ -z "$ServiceBusQueueName" ] || [ -z "$SubscriptionId" ]; then
    echo "SERVICE_BUS_CONNECTION__fullyQualifiedNamespace, SERVICE_BUS_QUEUE_NAME and AZURE_SUBSCRIPTION_ID are required in the azd environment." >&2
    exit 1
fi
if [[ ! $ServiceBusNamespace =~ ^[a-zA-Z0-9-]+\.servicebus\.windows\.net$ ||
      ! $ServiceBusQueueName =~ ^[a-zA-Z0-9._/-]+$ ||
      ! $SubscriptionId =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]; then
    echo "The azd environment contains an invalid Service Bus namespace, queue name or subscription ID." >&2
    exit 1
fi

settingsPath=./src/local.settings.json
if [ -e "$settingsPath" ] || [ -L "$settingsPath" ]; then
    echo "WARNING: src/local.settings.json already exists and was not changed or validated. Review these values under Values to use the provisioned resources:"
    echo "  ServiceBusConnection__fullyQualifiedNamespace = $ServiceBusNamespace"
    echo "  ServiceBusQueueName = $ServiceBusQueueName"
else
    cat > "$settingsPath" << EOF
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "java",
        "ServiceBusConnection__fullyQualifiedNamespace": "$ServiceBusNamespace",
        "ServiceBusQueueName": "$ServiceBusQueueName"
    }
}
EOF

    echo "src/local.settings.json has been created successfully!"
fi

echo "Creating/updating send-message.sh..."

cat > ./send-message.sh << EOF
#!/bin/bash
set -euo pipefail
az rest --subscription "$SubscriptionId" --method POST --uri "https://$ServiceBusNamespace/$ServiceBusQueueName/messages" --headers "Content-Type=application/atom+xml;type=entry;charset=utf-8" --body "Hello from the CLI" --resource "https://servicebus.azure.net"
EOF
chmod +x ./send-message.sh

echo "send-message.sh has been created successfully!"
echo ""
echo "Service Bus Namespace: $ServiceBusNamespace"
echo "Service Bus Queue: $ServiceBusQueueName"
echo ""
echo "With VNet enabled, local use requires private endpoint connectivity and DNS."
echo "You can now run the function locally with 'cd src && mvn clean package azure-functions:run'"
echo "Send test messages with './send-message.sh'"