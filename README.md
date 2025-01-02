# Cloudflare mTLS Certificate Management Script

A PowerShell script for managing mutual TLS (mTLS) certificates in Cloudflare, supporting certificate uploads and hostname associations.

## Features

- Upload CA certificates to Cloudflare
- Replace hostname associations automatically
- Support for both modern Bearer token and legacy API key authentication
- Optional private key upload capability 
- Automatic association checking and verification
- Detailed console output and logging
- Environment variable support for credentials

## Prerequisites

- PowerShell 5.1 or higher
- A Cloudflare account with API access
- A valid CA certificate for mTLS
- Required Cloudflare credentials:
  - API Token (recommended) or API Key
  - Account Email (for API Key auth)
  - Account ID
  - Zone ID

## Installation

1. Download the `Upload-CloudFlareCACert.ps1` script
2. Ensure you have your Cloudflare credentials ready
3. Have your CA certificate (and optional private key) files accessible

## Usage

### Using Bearer Token Authentication (Recommended)

```powershell
.\Upload-CloudFlareCACert.ps1 -CertificateFile "path\to\cert.pem" -Name "example.com" -AccountID "your_account_id" -ZoneId "your_zone_id" -CloudflareApiToken "your_bearer_token"
```

This will:
1. Upload the certificate
2. Display certificate details
3. Prompt whether to associate with hostname
4. If yes:
   - Replace any existing associations
   - Verify the association
   - Display association details
5. If no:
   - Display Zone ID for future use
6. Save results to log file

### Using Legacy API Key Authentication

```powershell
.\Upload-CloudFlareCACert.ps1 -CertificateFile "path\to\cert.pem" -Name "example.com" -AccountID "your_account_id" -ZoneId "your_zone_id" -CloudflareApiToken "your_api_key" -CloudflareEmail "your_email" -UseAuthKey
```

### Optional Parameters

- `-PrivateKeyFile`: Path to the private key file (optional)
- `-Name`: Hostname to associate with the certificate (required)
- `-ZoneId`: Cloudflare Zone ID for the domain (required)
- `-Verbose`: Enable detailed logging

### Environment Variables

The script supports the following environment variables:
- `CLOUDFLARE_API_TOKEN`: Cloudflare API Token
- `CLOUDFLARE_EMAIL`: Cloudflare Account Email
- `CLOUDFLARE_ACCOUNT_ID`: Cloudflare Account ID

## Certificate Associations

The script will:
1. Ask if you want to associate the certificate with the specified hostname
2. If you choose to associate:
   - Replace any existing hostname associations
   - Use the Cloudflare Zone API for association management
   - Verify the association was created successfully
   - Display all existing associations
3. If you choose not to associate:
   - Display the Zone ID for future use
4. Include all details in the log file

## Finding Your Zone ID

1. Log in to the Cloudflare dashboard
2. Select your domain
3. On the overview page, scroll down to find your Zone ID
4. You can also find it in the API section of your domain settings

## Troubleshooting

Common issues and solutions:
- Authentication errors
- Certificate format issues
- API rate limiting
- Association creation failures
- Invalid Zone ID errors

## License

MIT











