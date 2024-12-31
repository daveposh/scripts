#!/bin/bash

# Configuration
CA_NAME="Private Root CA"
CA_COUNTRY="US"
CA_STATE="Florida"
CA_LOCALITY="Orlando"
CA_ORGANIZATION="Private Org"
CA_ORGANIZATIONAL_UNIT="IT Department"
CA_COMMON_NAME="Private Root CA"
CA_EMAIL="admin@example.com"

# Create directory structure
mkdir -p ca/{certs,crl,newcerts,private}
chmod 700 ca/private
touch ca/index.txt
echo 1000 > ca/serial

# Generate CA private key
openssl genrsa -aes256 -out ca/private/ca.key 4096

# Generate CA root certificate
openssl req -new -x509 -days 3650 -key ca/private/ca.key \
    -out ca/certs/ca.crt \
    -subj "/C=$CA_COUNTRY/ST=$CA_STATE/L=$CA_LOCALITY/O=$CA_ORGANIZATION/OU=$CA_ORGANIZATIONAL_UNIT/CN=$CA_COMMON_NAME/emailAddress=$CA_EMAIL"

# Create OpenSSL configuration file
cat > ca/openssl.cnf << EOL
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = ./ca
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

private_key       = \$dir/private/ca.key
certificate       = \$dir/certs/ca.crt

crl               = \$dir/crl/ca.crl
crlnumber         = \$dir/crlnumber
crl_extensions    = crl_ext
default_crl_days  = 30

default_md        = sha256
name_opt         = ca_default
cert_opt         = ca_default
default_days     = 365
preserve         = no
policy           = policy_strict

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress           = optional

[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask        = utf8only
default_md         = sha256
x509_extensions    = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName            = State or Province Name
localityName                   = Locality Name
organizationName               = Organization Name
organizationalUnitName         = Organizational Unit Name
commonName                     = Common Name
emailAddress                   = Email Address

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOL

echo "CA creation complete!"
echo "Your CA certificate is in ca/certs/ca.crt"
echo "Your CA private key is in ca/private/ca.key"
