<#
.SYNOPSIS
    Uploads a CA certificate to Cloudflare for origin authentication.

.DESCRIPTION
    This script uploads a CA certificate to Cloudflare for use with origin authentication.
    It can be used to configure mutual TLS (mTLS) authentication for your Cloudflare-protected services.

.PARAMETER CertificateFile
    Path to the PEM-formatted CA certificate file.

.PARAMETER Hostname
    The hostname where this CA certificate will be applied.

.PARAMETER CloudflareApiToken
    Your Cloudflare API key (Global API Key). If not provided, the script will check the CLOUDFLARE_API_KEY environment variable,
    then look for a key file, and finally prompt for manual entry.

.PARAMETER CloudflareApiTokenFile
    Path to a file containing your Cloudflare API token.

.PARAMETER CloudflareZoneId
    Your Cloudflare Zone ID. If not provided, the script will check the CLOUDFLARE_ZONE_ID environment variable.

.PARAMETER CloudflareEmail
    Your Cloudflare account email. If not provided, the script will check the CLOUDFLARE_EMAIL environment variable,
    then prompt for manual entry.

.EXAMPLE
    # Using environment variables
    $env:CLOUDFLARE_API_KEY = "your-api-key"
    $env:CLOUDFLARE_EMAIL = "your-email@example.com"
    $env:CLOUDFLARE_ZONE_ID = "your-zone-id"
    .\Upload-CloudFlareCACert.ps1 -CertificateFile ".\ca.pem" -Hostname "api.example.com"

.EXAMPLE
    # Using direct parameters
    .\Upload-CloudFlareCACert.ps1 `
        -CertificateFile ".\ca.pem" `
        -Hostname "api.example.com" `
        -CloudflareApiToken "your-api-key" `
        -CloudflareEmail "your-email@example.com" `
        -CloudflareZoneId "your-zone-id"

.EXAMPLE
    # Using an API token file
    .\Upload-CloudFlareCACert.ps1 `
        -CertificateFile ".\ca.pem" `
        -Hostname "api.example.com" `
        -CloudflareApiTokenFile ".\token.txt" `
        -CloudflareZoneId "your-zone-id"

.EXAMPLE
    # Interactive mode (will prompt for API token)
    .\Upload-CloudFlareCACert.ps1 `
        -CertificateFile ".\ca.pem" `
        -Hostname "api.example.com" `
        -CloudflareZoneId "your-zone-id"

.NOTES
    Author: Your Name
    Last Modified: [Date]
    The script will look for credentials in this order:
    1. Direct parameters
    2. Environment variables
    3. API token file (if specified)
    4. Interactive prompt
#>

# Script parameters
param(
    [Parameter(Mandatory=$true)]
    [string]$CertificateFile,
    
    [Parameter(Mandatory=$true)]
    [string]$Hostname,
    
    [Parameter(Mandatory=$false)]
    [string]$CloudflareApiToken = $env:CLOUDFLARE_API_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$CloudflareApiTokenFile,
    
    [Parameter(Mandatory=$false)]
    [string]$CloudflareZoneId = $env:CLOUDFLARE_ZONE_ID,

    [Parameter(Mandatory=$false)]
    [string]$CloudflareEmail = $env:CLOUDFLARE_EMAIL
)

# Check for API token from file if provided
if ([string]::IsNullOrEmpty($CloudflareApiToken) -and -not [string]::IsNullOrEmpty($CloudflareApiTokenFile)) {
    if (Test-Path $CloudflareApiTokenFile) {
        $CloudflareApiToken = Get-Content $CloudflareApiTokenFile -Raw
        $CloudflareApiToken = $CloudflareApiToken.Trim()
    } else {
        throw "API token file not found at path: $CloudflareApiTokenFile"
    }
}

# If still no API token, prompt user
if ([string]::IsNullOrEmpty($CloudflareApiToken)) {
    $secureString = Read-Host -Prompt "Enter your Cloudflare API Token" -AsSecureString
    $CloudflareApiToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    )
}

# Validate API token is not empty
if ([string]::IsNullOrEmpty($CloudflareApiToken)) {
    throw "Cloudflare API Token is required. Please provide it through one of the available methods."
}

# Validate environment variables if not provided as parameters
if ([string]::IsNullOrEmpty($CloudflareApiToken)) {
    throw "Cloudflare API Token is not set. Please set CLOUDFLARE_API_TOKEN environment variable or provide it as a parameter."
}

# Check for Account ID in environment variables or parameters
if ([string]::IsNullOrEmpty($AccountId)) {
    $AccountId = $env:CLOUDFLARE_ACCOUNT_ID
}

# If still no Account ID, prompt user
if ([string]::IsNullOrEmpty($AccountId)) {
    $AccountId = Read-Host -Prompt "Enter your Cloudflare Account ID"
}

if ([string]::IsNullOrEmpty($AccountId)) {
    Write-Host "Error: Cloudflare Account ID is required" -ForegroundColor Red
    exit 1
}

# Verify certificate file exists
if (-not (Test-Path $CertificateFile)) {
    throw "Certificate file not found at path: $CertificateFile"
}

# Verify certificate format and display information
try {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificateFile)
    
    Write-Host "`nCertificate Information:" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan
    Write-Host "Target Host:  $Hostname" -ForegroundColor Green
    Write-Host "Subject:      $($cert.Subject)"
    Write-Host "Issuer:       $($cert.Issuer)"
    Write-Host "Valid From:   $($cert.NotBefore)"
    Write-Host "Valid To:     $($cert.NotAfter)"
    Write-Host "Thumbprint:   $($cert.Thumbprint)"
    Write-Host "Serial:       $($cert.SerialNumber)"
    Write-Host "------------------------`n" -ForegroundColor Cyan

    # Verify it's a CA certificate
    $isCA = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Basic Constraints" } | 
                              ForEach-Object { $_.Format(1) -match "Certificate Authority=True" }
    
    if (-not $isCA) {
        Write-Host "Warning: This certificate does not appear to be a CA certificate!" -ForegroundColor Yellow
    }

    $proceed = Read-Host "Do you want to proceed with uploading this certificate for hostname '$Hostname'? (Y/N)"
    if ($proceed -notmatch "^[Yy]$") {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        exit 0
    }

} catch {
    throw "Invalid certificate format. Please ensure the file is in PEM format: $_"
}

# Read and format certificate content
try {
    $certContent = Get-Content $CertificateFile -Raw
    $certContent = $certContent.Replace("`r`n", "\n").Replace("`n", "\n").TrimEnd("\n")
} catch {
    throw "Failed to read certificate file: $_"
}

# Prepare request headers and body
$headers = @{
    'Authorization' = "Bearer $CloudflareApiToken"
    'Content-Type' = 'application/json'
}

$body = @{
    certificate = $certContent
    name = "${Hostname}_ca_cert"
    type = "ca"
} | ConvertTo-Json

# Construct the API URL
$uri = "https://api.cloudflare.com/client/v4/accounts/$AccountId/mtls_certificates"

try {
    Write-Host "Uploading CA certificate for $Hostname..."
    
    # Make the API request
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    
    if ($response.success) {
        Write-Host "Successfully uploaded CA certificate" -ForegroundColor Green
        Write-Host "Certificate ID: $($response.result.id)" -ForegroundColor Green
    } else {
        Write-Host "Failed to upload certificate:" -ForegroundColor Red
        $response.errors | ForEach-Object {
            Write-Host "Error: $($_.message)" -ForegroundColor Red
        }
        exit 1
    }
} catch {
    Write-Host "Error making API request: $_" -ForegroundColor Red
    Write-Host "Response: $($_.ErrorDetails.Message)" -ForegroundColor Red
    exit 1
}