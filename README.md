# Cloudflare mTLS Certificate Management Script

A PowerShell script for managing mutual TLS (mTLS) certificates in Cloudflare, supporting both modern Bearer token and legacy API key authentication methods.

## Features

- Upload CA certificates to Cloudflare
- Support for both modern Bearer token and legacy API key authentication
- Optional private key upload capability 
- Automatic association checking
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

## Installation

1. Download the `Upload-CloudFlareCACert.ps1` script
2. Ensure you have your Cloudflare credentials ready
3. Have your CA certificate (and optional private key) files accessible

## Usage

.\Upload-CloudFlareCACert.ps1 -CertificatePath "path\to\cert.pem" -AccountID "your_account_id" -BearerToken "your_bearer_token"

### Using Bearer Token Authentication (Recommended)

.\Upload-CloudFlareCACert.ps1 -CertificatePath "path\to\cert.pem" -AccountID "your_account_id" -BearerToken "your_bearer_token"

### Using Legacy API Key Authentication

```powershell
.\Upload-CloudFlareCACert.ps1 -CertificatePath "path\to\cert.pem" -AccountID "your_account_id" -ApiKey "your_api_key" -Email "your_email"
```

### Optional Parameters

- `-PrivateKeyPath`: Path to the private key file (optional)
- `-Name`: Custom name for the certificate (default: filename)
- `-Verbose`: Enable detailed logging

### Environment Variables

The script supports the following environment variables:
- `CF_API_TOKEN`: Cloudflare API Token
- `CF_API_KEY`: Cloudflare API Key
- `CF_EMAIL`: Cloudflare Account Email
- `CF_ACCOUNT_ID`: Cloudflare Account ID

## Troubleshooting

Common issues and solutions:
- Authentication errors
- Certificate format issues
- API rate limiting

## License

MIT











