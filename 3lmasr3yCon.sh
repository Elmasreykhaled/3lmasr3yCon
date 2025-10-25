#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [-t <domain> | <domains_file>]"
    echo "  -t <domain> : Process a single domain"
    echo "  <domains_file> : Process a file containing a list of domains"
    exit 1
}

# Check for arguments
if [ $# -eq 0 ]; then
    usage
fi

# Initialize variables
DOMAINS_FILE=""
SINGLE_DOMAIN=""

# Parse arguments
while getopts "t:" opt; do
    case $opt in
        t)
            SINGLE_DOMAIN="$OPTARG"
            ;;
        \?)
            usage
            ;;
    esac
done

# If -t is not provided, treat the first argument as the domains file
if [ -z "$SINGLE_DOMAIN" ]; then
    if [ $# -eq 1 ]; then
        DOMAINS_FILE="$1"
        if [ ! -f "$DOMAINS_FILE" ]; then
            echo "Error: File $DOMAINS_FILE not found"
            exit 1
        fi
    else
        usage
    fi
fi

# Check if required scripts exist
for script in subdomains_wayback_port_nuclei.sh js_analyzer.sh get_hit_points.sh; do
    if [ ! -f "./$script" ]; then
        echo "Error: Required script $script not found in current directory"
        exit 1
    fi
done

# Process a single domain or a list of domains
if [ -n "$SINGLE_DOMAIN" ]; then
    DOMAINS=("$SINGLE_DOMAIN")
else
    # Read domains from file into an array
    mapfile -t DOMAINS < "$DOMAINS_FILE"
fi

# Loop through each domain
for domain in "${DOMAINS[@]}"; do
    # Skip empty lines
    [ -z "$domain" ] && continue

    echo "[*] Starting 3lmasr3yCon for domain: $domain"

    # Step 1: Run subdomains_wayback_port_nuclei.sh
    echo "[*] Running subdomain enumeration, port scanning, and nuclei..."
    ./subdomains_wayback_port_nuclei.sh -t "$domain" || {
        echo "[!] Error: subdomains_wayback_port_nuclei.sh failed for $domain"
        continue
    }
    echo "[+] Subdomain enumeration and scanning complete for $domain"

    # Step 2: Run js_analyzer.sh on live_waymore.txt
    LIVE_WAYMORE="$domain/live_waymore.txt"
    if [ -f "$LIVE_WAYMORE" ]; then
        echo "[*] Running js_analyzer.sh on $LIVE_WAYMORE..."
        ./js_analyzer.sh "$LIVE_WAYMORE" || {
            echo "[!] Error: js_analyzer.sh failed for $LIVE_WAYMORE"
        }
        echo "[+] JS analysis complete for $domain"
        mv js "$domain/js"
    else
        echo "[!] Warning: $LIVE_WAYMORE not found, skipping js_analyzer.sh"
    fi

    # Step 3: Run get_hit_points.sh on live_waymore.txt
    if [ -f "$LIVE_WAYMORE" ]; then
        echo "[*] Running get_hit_points.sh on $LIVE_WAYMORE..."
        ./get_hit_points.sh "$LIVE_WAYMORE" || {
            echo "[!] Error: get_hit_points.sh failed for $LIVE_WAYMORE"
        }
        echo "[+] Hit points analysis complete for $domain"
        mv hit_points "$domain/hit_points"
    else
        echo "[!] Warning: $LIVE_WAYMORE not found, skipping get_hit_points.sh"
    fi

   echo "[+] Finished processing $domain"
done

echo "[+] 3lmasr3yCon completed. Results are in respective domain directories."
