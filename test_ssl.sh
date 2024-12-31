#!/bin/bash

# Define the function at the start of the script
perform_get_request() {
    echo -e "\n=== HTTP Response ===\n"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="response_${timestamp}.html"
    
    echo "Saving response to: $filename"
    
    (printf "GET / HTTP/1.1\r\nHost: $(echo "$URL" | sed 's|https://||' | sed 's|/.*||')\r\nConnection: close\r\n\r\n") | \
    openssl s_client -connect "$(echo "$CONNECT_URL" | sed 's|https://||' | sed 's|/.*||'):443" -servername "$(echo "$URL" | sed 's|https://||' | sed 's|/.*||')" -ign_eof 2>/dev/null | \
    sed '1,/^\r$/d' > "$filename"
    
    # Check if file was created and has content
    if [ -f "$filename" ] && [ -s "$filename" ]; then
        echo "Response saved successfully"
        echo "File size: $(wc -c < "$filename") bytes"
    else
        echo "Error: Failed to save response or response was empty"
        rm -f "$filename"
    fi
}

# Default values
URL=""
REQUEST_URL=""
CONNECT_URL=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            URL="$2"
            shift 2
            ;;
        -r|--request-url)
            REQUEST_URL="Referer: $2"
            shift 2
            ;;
        -c|--connect)
            CONNECT_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Check if URLs are provided
if [ -z "$URL" ] || [ -z "$CONNECT_URL" ]; then
    echo "Error: Both URL and CONNECT_URL are required"
    echo "Usage: $0 -u|--url <request_host> -c|--connect <connect_host> [-r|--request-url <request_url>]"
    exit 1
fi

# Show certificates first
if [ ! -z "$REQUEST_URL" ]; then
    echo "Certificate Chain Information:" && \
    (echo "HEAD / HTTP/1.1"; echo "Host: $(echo "$URL" | sed 's|https://||' | sed 's|/.*||')"; echo "$REQUEST_URL"; echo) | \
    openssl s_client -connect "$(echo "$CONNECT_URL" | sed 's|https://||' | sed 's|/.*||'):443" -servername "$(echo "$URL" | sed 's|https://||' | sed 's|/.*||')" -showcerts 2>/dev/null | \
    awk '/-----BEGIN CERTIFICATE-----/{i++}i' | \
    while read line; do
        if [[ $line == *"BEGIN CERTIFICATE"* ]]; then
            echo -e "\n=== Certificate $((++n)) ===";
            echo "$line" > temp.crt;
        elif [[ $line == *"END CERTIFICATE"* ]]; then
            echo "$line" >> temp.crt;
            openssl x509 -noout -subject -serial -in temp.crt | sed 's/subject=//g' | sed 's/serial=//g';
            rm temp.crt;
        else
            echo "$line" >> temp.crt;
        fi
    done
else
    echo "Certificate Chain Information:" && \
    (echo "HEAD / HTTP/1.1"; echo "Host: $(echo "$URL" | sed 's|https://||' | sed 's|/.*||')"; echo) | \
    openssl s_client -connect "$(echo "$CONNECT_URL" | sed 's|https://||' | sed 's|/.*||'):443" -servername "$(echo "$URL" | sed 's|https://||' | sed 's|/.*||')" -showcerts 2>/dev/null | \
    awk '/-----BEGIN CERTIFICATE-----/{i++}i' | \
    while read line; do
        if [[ $line == *"BEGIN CERTIFICATE"* ]]; then
            echo -e "\n=== Certificate $((++n)) ===";
            echo "$line" > temp.crt;
        elif [[ $line == *"END CERTIFICATE"* ]]; then
            echo "$line" >> temp.crt;
            openssl x509 -noout -subject -serial -in temp.crt | sed 's/subject=//g' | sed 's/serial=//g';
            rm temp.crt;
        else
            echo "$line" >> temp.crt;
        fi
    done
fi

# Now perform the GET request
perform_get_request
