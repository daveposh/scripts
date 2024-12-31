# Cloudflare mTLS Certificate Management Script

A PowerShell script for managing Cloudflare mTLS certificates, including uploading CA certificates and checking their associations.

## Features

- Upload CA certificates to Cloudflare for mTLS authentication
- Support for both modern Bearer token and legacy API key authentication
- Optional private key upload capability
- Automatic association checking after upload
- Detailed console output with color-coded information
- Comprehensive logging of operations
- Environment variable support for sensitive credentials

## Prerequisites

- PowerShell 5.1 or higher
- Cloudflare account with API access
- Required Cloudflare credentials:
  - API Token (recommended) or API Key
  - Account Email (for API Key authentication)
  - Account ID

## Installation

1. Clone this repository or download the `Upload-CloudFlareCACert.ps1` script
2. Ensure you have your Cloudflare credentials ready
3. (Optional) Set up environment variables for credentials:
   ```powershell
   $env:CLOUDFLARE_API_TOKEN = "your-api-token"
   $env:CLOUDFLARE_EMAIL = "your-email"
   $env:CLOUDFLARE_ACCOUNT_ID = "your-account-id"
   ```

## Usage

### Using Bearer Token Authentication (Recommended)
