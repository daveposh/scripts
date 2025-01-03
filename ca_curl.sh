#!/bin/bash

# Check if required environment variables are set
if [ -z "$ACCOUNT_ID" ] || [ -z "$API_TOKEN" ] || [ -z "$NAME" ]; then
    echo "Please set required environment variables:"
    echo "export ACCOUNT_ID=\"your_account_id\""
    echo "export API_TOKEN=\"your_api_token\""
    echo "export NAME=\"your_cert_name\""
    exit 1
fi

# Check if certificate file exists
if [ ! -f "ca.crt" ]; then
    echo "Error: ca.crt file not found in current directory"
    exit 1
fi

# Upload certificate
echo "Uploading CA certificate to Cloudflare..."
curl -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/mtls_certificates" -H "Authorization: Bearer ${API_TOKEN}" -H "Content-Type: application/json" --data "{\"name\": \"${NAME}_ca_cert_for_mtls\", \"certificates\": \"$(cat ca.crt | sed 's/$/\\n/' | tr -d '\n')\", \"ca\": true, \"type\": \"ca\"}"

echo -e "\nDone!"
