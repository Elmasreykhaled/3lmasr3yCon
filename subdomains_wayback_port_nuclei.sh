#!/bin/bash

# Function to handle Ctrl+C (skip current tool and continue)
handle_interrupt() {
    echo -e "\n[!] Ctrl+C detected, skipping current tool..."
    # Kill the current process (if any) and continue the loop
    kill -9 $$ 2>/dev/null
}

# Trap Ctrl+C (SIGINT) and call handle_interrupt
trap handle_interrupt SIGINT

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

    echo "Processing domain: $domain"

    # 1. Create directory for the domain
    mkdir -p "$domain"
    cd "$domain" || exit

    # 2. Create subdomains directory and run subdomain enumeration tools
    mkdir -p subdomains
    echo "Running subdomain enumeration for $domain..."

    # Subfinder
    echo "Running subfinder..."
    ~/go/bin/subfinder -d "$domain" -o subdomains/subfinder.txt || echo "Subfinder failed, skipping..."

    # Assetfinder
    echo "Running assetfinder..."
    ~/go/bin/assetfinder --subs-only "$domain" > subdomains/assetfinder.txt || echo "Assetfinder failed, skipping..."

    # Github-subdomains (requires GitHub token)
    echo "Running github-subdomains..."
    ~/go/bin/github-subdomains -d "$domain"  -t "$GITHUB_TOKEN" -o subdomains/github-subdomains.txt || echo "Github-subdomains failed, skipping..."

    # Chaos (requires Chaos API key)
    echo "Running chaos..."
    ~/go/bin/chaos -d "$domain" -key "$CHAOS_KEY" -o subdomains/chaos.txt || echo "Chaos failed, skipping..."

    # Findomain
    echo "Running findomain..."
    findomain -t "$domain" -u subdomains/findomain.txt || echo "Findomain failed, skipping..."

    # Combine and deduplicate subdomains
    echo "Combining and deduplicating subdomains..."
    cat subdomains/*.txt 2>/dev/null | sort -u > subdomains/all_collected_subdomains.txt

    # 3. Use httpx to get live subdomains from all_collected_subdomains.txt
    echo "Checking live subdomains from all_collected_subdomains.txt..."
    ~/go/bin/httpx -silent -l subdomains/all_collected_subdomains.txt -silent -o subdomains/live_all_collected_subdomains.txt || echo "Httpx failed, skipping..."

    # 4. Third-level subdomain enumeration
    echo "Running third-level subdomain enumeration for $domain..."
    if [ -s subdomains/live_all_collected_subdomains.txt ]; then
        # Run subfinder, assetfinder, and findomain on each live second-level subdomain
        while IFS= read -r subdomain; do
            ~/go/bin/subfinder -d "$subdomain" -o subdomains/temp_subfinder_third.txt || echo "Subfinder (third-level) failed, skipping..."
            ~/go/bin/assetfinder --subs-only "$subdomain" > subdomains/temp_assetfinder_third.txt || echo "Assetfinder (third-level) failed, skipping..."
            findomain -t "$subdomain" -u subdomains/temp_findomain_third.txt || echo "Findomain (third-level) failed, skipping..."
        done < subdomains/live_all_collected_subdomains.txt
        # Combine and deduplicate third-level results
        cat subdomains/temp_*.txt 2>/dev/null | sort -u > subdomains/third.txt
        rm subdomains/temp_*.txt 2>/dev/null
    else
        echo "No live second-level subdomains found for third-level enumeration"
        touch subdomains/third.txt
    fi

    # 5. Combine and deduplicate third.txt and live_all_collected_subdomains.txt
    echo "Creating final deduplicated subdomain list..."
    cat subdomains/live_all_collected_subdomains.txt subdomains/third.txt 2>/dev/null | sort -u > subdomains/final_collected_subdomains.txt

    # 6. Use httpx to get live subdomains from final_collected_subdomains.txt
    echo "Checking live subdomains from final_collected_subdomains.txt..."
    ~/go/bin/httpx -silent -l subdomains/final_collected_subdomains.txt -silent -o live_subdomains.txt || echo "Httpx failed, skipping..."

    # 7. Run naabu for port scanning
    echo "Running port scan on live subdomains..."
    sudo ~/go/bin/naabu -l live_subdomains.txt  -silent -o port_scan.txt || echo "Naabu failed, skipping..."

    # 8. Run waymore for wayback URLs
    echo "Fetching wayback URLs for $domain..."
    waymore -mode U -i "$domain" -oU waymore.txt || echo "Waymore failed, skipping..."

    # 9. Run httpx for wayback URLs
    echo "Checking live wayback URLs for $domain..."
    ~/go/bin/httpx -silent -l waymore.txt -silent -o live_waymore.txt || echo "Httpx failed, skipping..."

    # 10. Run nuclei for vulnerability scanning
    echo "Running nuclei vulnerability scan..."
    ~/go/bin/nuclei -silent -si 30 -l live_subdomains.txt -es info,low -etags network -o nuclei.txt || echo "Nuclei failed, skipping..."

    echo "Finished processing $domain"
    cd .. || exit

done
