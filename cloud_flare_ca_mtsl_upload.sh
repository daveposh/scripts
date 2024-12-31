#!/bin/bash

# Check if required environment variables are set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Error: CLOUDFLARE_API_TOKEN environment variable is not set"
    exit 1
fi

if [ -z "$CLOUDFLARE_ZONE_ID" ]; then
    echo "Error: CLOUDFLARE_ZONE_ID environment variable is not set"
    exit 1
fi

# Check if required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <ca_certificate_file> <hostname>"
    echo "Example: $0 ./ca.pem api.example.com"
    exit 1
fi

CA_CERT_FILE=$1
HOSTNAME=$2

# Check if certificate file exists
if [ ! -f "$CA_CERT_FILE" ]; then
    echo "Error: Certificate file $CA_CERT_FILE does not exist"
    exit 1
fi

# Read certificate content
CERT_CONTENT=$(cat "$CA_CERT_FILE" | sed 's/$/\\n/' | tr -d '\n')

# Create JSON payload
JSON_DATA="{
    \"certificate\": \"${CERT_CONTENT}\",
    \"name\": \"${HOSTNAME}_ca_cert\",
    \"type\": \"ca\"
}"

# Upload certificate to Cloudflare
echo "Uploading CA certificate for ${HOSTNAME}..."
RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/mtls_certificates" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$JSON_DATA")

# Check if upload was successful
if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "Successfully uploaded CA certificate"
    CERT_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    echo "Certificate ID: $CERT_ID"
else
    echo "Error uploading certificate:"
    echo "$RESPONSE"
    exit 1
fi
