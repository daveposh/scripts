<#
.SYNOPSIS
    Uploads a CA certificate to Cloudflare for mTLS, creates hostname associations, and checks existing associations.

.DESCRIPTION
    This script uploads a CA certificate to Cloudflare for mutual TLS (mTLS) authentication,
    creates an association with the specified hostname, and verifies any existing associations. 
    It supports both modern Bearer token and legacy API key authentication methods.

.PARAMETER CertificateFile
    Path to the CA certificate file to upload.

.PARAMETER PrivateKeyFile
    Optional. Path to the private key file if you want to upload it with the certificate.

.PARAMETER Name
    Name to use for the certificate name in Cloudflare. This will also be used as the hostname
    for the mTLS association.

.PARAMETER ZoneId
    Cloudflare zone ID. Can also be set via CLOUDFLARE_ZONE_ID environment variable.

.PARAMETER CloudflareApiToken
    Cloudflare API token for authentication. Can also be set via CLOUDFLARE_API_TOKEN environment variable.

.PARAMETER CloudflareEmail
    Cloudflare account email. Required when using API key authentication. Can also be set via CLOUDFLARE_EMAIL environment variable.

.PARAMETER AccountId
    Cloudflare account ID. Can also be set via CLOUDFLARE_ACCOUNT_ID environment variable.

.PARAMETER UseAuthKey
    Switch to use legacy API key authentication instead of Bearer token.

.EXAMPLE
    # Using Bearer token authentication (recommended)
    .\Upload-CloudFlareCACert.ps1 -CertificateFile "cert.pem" -Name "example.com" -CloudflareApiToken "your-token" -AccountId "your-account-id"
    # This will upload the certificate and associate it with example.com

.EXAMPLE
    # Using API key authentication
    .\Upload-CloudFlareCACert.ps1 -CertificateFile "cert.pem" -Name "example.com" -CloudflareApiToken "your-key" -CloudflareEmail "your-email" -AccountId "your-account-id" -UseAuthKey

.EXAMPLE
    # Including private key
    .\Upload-CloudFlareCACert.ps1 -CertificateFile "cert.pem" -PrivateKeyFile "key.pem" -Name "example.com" -CloudflareApiToken "your-token" -AccountId "your-account-id"

.NOTES
    The script will:
    1. Upload the CA certificate to Cloudflare
    2. Display the certificate details
    3. Create an mTLS association with the specified hostname
    4. Check and display any existing mTLS associations
    5. Save both certificate details and associations to a log file

.FUNCTIONALITY
    - Uploads CA certificates to Cloudflare
    - Creates hostname associations automatically
    - Supports both modern and legacy authentication methods
    - Optional private key upload
    - Automatic association checking
    - Detailed console output
    - Log file generation
#>

# Script parameters
param(
    [Parameter(Mandatory=$true)]
    [string]$CertificateFile,
    
    [Parameter(Mandatory=$false)]
    [string]$PrivateKeyFile,
    
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [Parameter(Mandatory=$true)]
    [string]$ZoneId,
    
    [Parameter(Mandatory=$false)]
    [string]$CloudflareApiToken = $env:CLOUDFLARE_API_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$CloudflareEmail = $env:CLOUDFLARE_EMAIL,
    
    [Parameter(Mandatory=$false)]
    [string]$AccountId = $env:CLOUDFLARE_ACCOUNT_ID,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseAuthKey
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
    Write-Host "Target Host:  $Name" -ForegroundColor Green
    Write-Host "Subject:      $($cert.Subject)"
    Write-Host "Issuer:       $($cert.Issuer)"
    Write-Host "Valid From:   $($cert.NotBefore)"
    Write-Host "Valid To:     $($cert.NotAfter)"
    Write-Host "Thumbprint:   $($cert.Thumbprint)"
    Write-Host "Serial:       $($cert.SerialNumber)"
    Write-Host "------------------------`n" -ForegroundColor Cyan

    # Verify it's a CA certificate - fixed validation
    $basicConstraints = $cert.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.19" }
    $isCA = $false
    if ($basicConstraints) {
        try {
            # Convert the extension to BasicConstraints type to safely check CA flag
            $basicConstraintsExt = [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]$basicConstraints
            $isCA = $basicConstraintsExt.CertificateAuthority
        } catch {
            Write-Host "Warning: Could not parse Basic Constraints extension. Error: $_" -ForegroundColor Yellow
        }
    }
    
    if (-not $isCA) {
        Write-Host "Warning: This certificate does not appear to be a CA certificate!" -ForegroundColor Yellow
        Write-Host "The Basic Constraints extension either doesn't exist or doesn't indicate this is a CA." -ForegroundColor Yellow
        $proceed = Read-Host "Are you sure you want to continue? (Y/N)"
        if ($proceed -notmatch "^[Yy]$") {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Host "Verified: This is a CA certificate" -ForegroundColor Green
    }

    $proceed = Read-Host "Do you want to proceed with uploading this certificate for name '$Name'? (Y/N)"
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

# Read private key if provided
$privateKey = $null
if ($PrivateKeyFile) {
    if (Test-Path $PrivateKeyFile) {
        $privateKey = Get-Content $PrivateKeyFile -Raw
        $privateKey = $privateKey.Replace("`r`n", "\n").Replace("`n", "\n").TrimEnd("\n")
    } else {
        throw "Private key file not found at path: $PrivateKeyFile"
    }
}

# Prepare request headers based on authentication method
$headers = @{
    'Content-Type' = 'application/json'
}

if ($UseAuthKey) {
    $headers['X-Auth-Email'] = $CloudflareEmail
    $headers['X-Auth-Key'] = $CloudflareApiToken
} else {
    $headers['Authorization'] = "Bearer $CloudflareApiToken"
}

# Prepare request body
$body = @{
    certificates = $certContent
    name = "${Name}_ca_cert_for_mtls"
    ca = $true
}

# Add private key if provided
if ($privateKey) {
    $body['private_key'] = $privateKey
}

$body = $body | ConvertTo-Json

# Construct the API URL
$uri = "https://api.cloudflare.com/client/v4/accounts/$AccountId/mtls_certificates"

# Add new function to check associations
function Get-MTLSAssociations {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CertificateId,
        [Parameter(Mandatory=$true)]
        [string]$AccountId,
        [Parameter(Mandatory=$true)]
        [hashtable]$Headers
    )

    $uri = "https://api.cloudflare.com/client/v4/accounts/$AccountId/mtls_certificates/$CertificateId/associations"
    
    try {
        Write-Host "`nChecking mTLS certificate associations..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $Headers
        
        if ($response.success) {
            if ($response.result.Count -eq 0) {
                Write-Host "No associations found for this certificate." -ForegroundColor Yellow
            } else {
                Write-Host "`nCertificate Associations:" -ForegroundColor Cyan
                Write-Host "------------------------" -ForegroundColor Cyan
                foreach ($association in $response.result) {
                    $association.PSObject.Properties | ForEach-Object {
                        Write-Host "$($_.Name): $($_.Value)" -ForegroundColor Green
                    }
                    Write-Host "------------------------" -ForegroundColor Cyan
                }
            }
            return $response.result
        } else {
            Write-Host "Failed to retrieve associations:" -ForegroundColor Red
            $response.errors | ForEach-Object {
                Write-Host "Error: $($_.message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Error checking associations: $_" -ForegroundColor Red
        Write-Host "Response: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

# Add new function to associate certificate with hostname
function Set-MTLSAssociation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CertificateId,
        [Parameter(Mandatory=$true)]
        [string]$Hostname,
        [Parameter(Mandatory=$true)]
        [string]$ZoneId,
        [Parameter(Mandatory=$true)]
        [hashtable]$Headers
    )

    $uri = "https://api.cloudflare.com/client/v4/zones/$ZoneId/certificate_authorities/hostname_associations"
    
    # Create the association body
    $body = @{
        ca_hostname_associations = @(
            @{
                hostname = $Hostname
                ca_id = $CertificateId
            }
        )
    } | ConvertTo-Json

    try {
        Write-Host "`nReplacing hostname associations for $Hostname..." -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri $uri -Method Put -Headers $Headers -Body $body
        
        if ($response.success) {
            Write-Host "Successfully updated hostname associations" -ForegroundColor Green
            Write-Host "Associated $Hostname with certificate $CertificateId" -ForegroundColor Green
            return $response.result
        } else {
            Write-Host "Failed to update associations:" -ForegroundColor Red
            $response.errors | ForEach-Object {
                Write-Host "Error: $($_.message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Error updating associations: $_" -ForegroundColor Red
        Write-Host "Response: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

try {
    Write-Host "Uploading CA certificate for $Name..."
    
    # Make the API request
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    
    if ($response.success) {
        Write-Host "Successfully uploaded CA certificate" -ForegroundColor Green
        $certId = $response.result.id

        # Create association with hostname using new ZoneId parameter
        $association = Set-MTLSAssociation -CertificateId $certId -Hostname $Name -ZoneId $ZoneId -Headers $headers
        
        # Print all result fields
        Write-Host "`nCertificate Details:" -ForegroundColor Cyan
        Write-Host "------------------------" -ForegroundColor Cyan
        $response.result.PSObject.Properties | ForEach-Object {
            if ($_.Name -eq "id") {
                Write-Host "`nCertificate ID: " -NoNewline -ForegroundColor Yellow
                Write-Host "$($_.Value)" -ForegroundColor White -BackgroundColor DarkBlue
                Write-Host ""
                
                # Check associations for the newly uploaded certificate
                $associations = Get-MTLSAssociations -CertificateId $_.Value -AccountId $AccountId -Headers $headers
                
                # Add associations to log file
                $logContent = @{
                    certificate = $response.result
                    associations = $associations
                }
                $logFile = "cloudflare_cert_upload_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                $logContent | ConvertTo-Json -Depth 10 | Out-File $logFile
                Write-Host "`nResults saved to: $logFile" -ForegroundColor Green
            } else {
                Write-Host "$($_.Name): $($_.Value)" -ForegroundColor Green
            }
        }
        Write-Host "------------------------`n" -ForegroundColor Cyan
        
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