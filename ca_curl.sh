#!/bin/bash

# List certificates command
list_certificates() {
    echo "Listing CA certificates..."
    curl -X GET "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/mtls_certificates" \
         -H "Authorization: Bearer ${API_TOKEN}" \
         -H "Content-Type: application/json"
}

# Associate certificate command
associate_certificate() {
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "Usage: associate_certificate <cert_id> <hostname> <zone_id>"
        return 1
    fi
    
    local CERT_ID="$1"
    local HOSTNAME="$2"
    local ZONE_ID="$3"

    echo "Creating association for certificate ${CERT_ID} with hostname ${HOSTNAME}..."
    curl -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/certificate_authorities/hostname_associations" \
         -H "Authorization: Bearer ${API_TOKEN}" \
         -H "Content-Type: application/json" \
         --data "{
           \"ca_hostname_associations\": [{
             \"hostname\": \"${HOSTNAME}\",
             \"ca_id\": \"${CERT_ID}\"
           }]
         }"
}

# Check if required environment variables are set
if [ -z "$ACCOUNT_ID" ] || [ -z "$API_TOKEN" ] || [ -z "$NAME" ]; then
    echo "Please set required environment variables:"
    echo "export ACCOUNT_ID=\"your_account_id\""
    echo "export API_TOKEN=\"your_api_token\""
    echo "export NAME=\"your_cert_name\""
    exit 1
fi

# One-line commands for reference
echo "Available commands:"
echo "1. Upload certificate:"
echo "curl -X POST \"https://api.cloudflare.com/client/v4/accounts/\${ACCOUNT_ID}/mtls_certificates\" -H \"Authorization: Bearer \${API_TOKEN}\" -H \"Content-Type: application/json\" --data \"{\\\"name\\\": \\\"\${NAME}_ca_cert_for_mtls\\\", \\\"certificates\\\": \\\"$(cat ca.crt | sed 's/$/\\n/' | tr -d '\n')\\\", \\\"ca\\\": true, \\\"type\\\": \\\"ca\\\"}\""
echo
echo "2. List certificates:"
echo "curl -X GET \"https://api.cloudflare.com/client/v4/accounts/\${ACCOUNT_ID}/mtls_certificates\" -H \"Authorization: Bearer \${API_TOKEN}\" -H \"Content-Type: application/json\""
echo
echo "3. Create association:"
echo "curl -X PUT \"https://api.cloudflare.com/client/v4/zones/\${ZONE_ID}/certificate_authorities/hostname_associations\" -H \"Authorization: Bearer \${API_TOKEN}\" -H \"Content-Type: application/json\" --data '{\"ca_hostname_associations\": [{\"hostname\": \"\${HOSTNAME}\", \"ca_id\": \"\${CERT_ID}\"}]}'"

# Check if certificate file exists
if [ ! -f "ca.crt" ]; then
    echo "Error: ca.crt file not found in current directory"
    exit 1
fi

# Upload certificate
echo "Uploading CA certificate to Cloudflare..."
curl -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/mtls_certificates" \
     -H "Authorization: Bearer ${API_TOKEN}" \
     -H "Content-Type: application/json" \
     --data "{
       \"name\": \"${NAME}_ca_cert_for_mtls\",
       \"certificates\": \"$(cat ca.crt | sed 's/$/\\n/' | tr -d '\n')\",
       \"ca\": true,
       \"type\": \"ca\"
     }"

echo -e "\nDone!"
