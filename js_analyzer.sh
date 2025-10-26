#!/bin/bash

# Check if a path to live_waymore.txt is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <path_to_live_waymore.txt>"
    exit 1
fi

WAYMORE_FILE="$PWD/$1"

# Check if live_waymore.txt exists
echo "[*] Checking for input file: $WAYMORE_FILE"
if [ ! -f "$WAYMORE_FILE" ]; then
    echo "[!] Error: $WAYMORE_FILE not found!"
    exit 1
fi

# Check if js-beautify is installed
if ! command -v js-beautify &> /dev/null; then
    echo "[!] Error: js-beautify not found. Please install it using 'npm install -g js-beautify'"
    exit 1
fi

# Check if trufflehog is installed
if ! command -v trufflehog &> /dev/null; then
    echo "[!] Error: trufflehog not found. Please install it using 'go install github.com/trufflesecurity/trufflehog@latest'"
    exit 1
fi

# Check if xnLinkFinder is available
if ! command -v xnLinkFinder &> /dev/null; then
    echo "[!] Error: xnLinkFinder not found. Please clone https://github.com/xnl-h4ck3r/xnLinkFinder.git, install requirements (pip install -r requirements.txt), and ensure xnLinkFinder is in PATH"
    exit 1
fi

# Define the js directory
js="js"

# Initialize download error log
ERROR_LOG="$js/download_errors.log"
echo "[*] Initializing download error log: $ERROR_LOG"
mkdir -p "$js" || { echo "[!] Error: Failed to create directory $js"; exit 1; }
: > "$ERROR_LOG" || { echo "[!] Error: Failed to create $ERROR_LOG"; exit 1; }
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log initialized" >> "$ERROR_LOG"

# Step 1: Create main js directory
echo "[*] Creating main directory: $js"
mkdir -p "$js" || { echo "[!] Error: Failed to create directory $js"; exit 1; }

# Step 2: Extract JS URLs using subjs
echo "[*] Extracting JS URLs using subjs..."
cat "$WAYMORE_FILE" | subjs > "$js/js_subjs.txt" || { echo "[!] Error: Failed to run subjs"; exit 1; }
echo "[+] Saved subjs output to $js/js_subjs.txt"

# Step 3: Extract JS URLs using grep
echo "[*] Extracting JS URLs using grep..."
cat "$WAYMORE_FILE" | grep -E '\.js(\?.*)?$' > "$js/js_waymore.txt"
ret=$?
if [ $ret -eq 2 ]; then
    echo "[!] Error: Failed to grep .js URLs"
    exit 1
fi
# If ret=1, no matches, which is okay; ret=0, matches
echo "[+] Saved grep output to $js/js_waymore.txt"

# Step 4: Merge results, remove duplicates, and clean up temporary files
echo "[*] Merging and deduplicating JS URLs..."
cat "$js/js_subjs.txt" "$js/js_waymore.txt" | sort -u > "$js/js_urls.txt" || { echo "[!] Error: Failed to merge and sort URLs"; exit 1; }
echo "[+] Merged URLs saved to $js/js_urls.txt"
echo "[*] Cleaning up temporary files..."
rm "$js/js_subjs.txt" "$js/js_waymore.txt" || { echo "[!] Error: Failed to remove temporary files"; exit 1; }
echo "[+] Temporary files removed"

# Check if any JS URLs were found
if [ ! -s "$js/js_urls.txt" ]; then
    echo "[!] No JS URLs found from both subjs and live_waymore.txt"
    exit 1
fi

# Step 5: Download JS files
echo "[*] Creating directory for JS files: $js/js_files"
mkdir -p "$js/js_files" || { echo "[!] Error: Failed to create js_files directory"; exit 1; }
echo "[*] Downloading JS files..."
while IFS= read -r url; do
    # Skip empty lines
    [ -z "$url" ] && continue
    # Validate URL (basic check for http(s) scheme)
    if ! echo "$url" | grep -qE '^https?://'; then
        echo "[!] Skipping invalid URL: $url"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skipped invalid URL: $url" >> "$ERROR_LOG"
        continue
    fi
    # Generate a safe filename from URL
    filename=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g').js
    echo "[*] Downloading $url to $js/js_files/$filename"
    # Download with retries, user-agent, and timeout
    if ! curl -s -L --fail --retry 3 --retry-delay 2 --connect-timeout 10 \
         -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
         "$url" -o "$js/js_files/$filename"; then
        echo "[!] Failed to download $url (check network or server response)"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to download $url (check network or server response)" >> "$ERROR_LOG"
    fi
    # Small delay to avoid rate limiting
    sleep 1
done < "$js/js_urls.txt"
echo "[+] JS files download complete"
if [ -s "$ERROR_LOG" ]; then
    echo "[*] Download errors logged to $ERROR_LOG"
fi

# Step 6: Beautify JS files
echo "[*] Creating directory for beautified JS files: $js/js_files_beautified"
mkdir -p "$js/js_files_beautified" || { echo "[!] Error: Failed to create js_files_beautified directory"; exit 1; }
echo "[*] Beautifying JS files using js-beautify..."
for file in "$js/js_files"/*.js; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "[*] Beautifying $filename"
        js-beautify "$file" > "$js/js_files_beautified/$filename" 2>/dev/null || { echo "[!] Warning: Failed to beautify $filename"; continue; }
        echo "[+] Beautified $filename saved to $js/js_files_beautified/$filename"
    else
        echo "[!] No JS files found in $js/js_files"
        break
    fi
done
echo "[+] JS files beautification complete"

# Step 7: Scan beautified JS files for secrets using TruffleHog
echo "[*] Creating directory for TruffleHog secrets: $js/trufflehog_secrets"
mkdir -p "$js/trufflehog_secrets" || { echo "[!] Error: Failed to create trufflehog_secrets directory"; exit 1; }
echo "[*] Scanning beautified JS files using TruffleHog..."
if [ -d "$js/js_files_beautified" ] && [ "$(ls -A "$js/js_files_beautified")" ]; then
    trufflehog filesystem "$js/js_files_beautified" --json > "$js/trufflehog_secrets/secrets.json" 2>/dev/null || { echo "[!] Warning: TruffleHog scan failed (check permissions or tool config)"; }
    if [ -s "$js/trufflehog_secrets/secrets.json" ]; then
        echo "[+] TruffleHog secrets found and saved to $js/trufflehog_secrets/secrets.json"
    else
        echo "[+] No secrets detected by TruffleHog (results saved to $js/trufflehog_secrets/secrets.json)"
    fi
else
    echo "[!] No beautified JS files to scan with TruffleHog"
fi
echo "[+] TruffleHog scan complete"

# Step 8: Create a scope filter file using the current directory name
echo "[*] Creating scope filter file for *.$(basename $(pwd))..."
> "$js/scope.txt" || { echo "[!] Error: Failed to create $js/scope.txt"; exit 1; }
echo "*.$(basename $(pwd))" > "$js/scope.txt"
if [ -s "$js/scope.txt" ]; then
    echo "[+] Scope filter file created at $js/scope.txt"
else
    echo "[!] Error: Failed to create scope filter file"
    exit 1
fi

# Step 9: Extract endpoints from JS URLs using xnLinkFinder
echo "[*] Creating directory for xnLinkFinder endpoints: $js/xnlinkfinder"
mkdir -p "$js/xnlinkfinder" || { echo "[!] Error: Failed to create xnlinkfinder directory"; exit 1; }
echo "[*] Extracting endpoints using xnLinkFinder..."
if [ -s "$js/js_urls.txt" ]; then
    xnLinkFinder -i "$js/js_urls.txt" -sf "$js/scope.txt" --origin -spo -inc -vv -u desktop -d 10 -o "$js/xnlinkfinder/endpoint.txt" -op "$js/xnlinkfinder/parameter.txt" -owl "$js/xnlinkfinder/wordlist.txt"
    if [ -s "$js/xnlinkfinder/endpoint.txt" ]; then
        echo "[+] Endpoints saved to $js/xnlinkfinder/endpoint.txt"
    else
        echo "[+] No endpoints detected by xnLinkFinder (results saved to $js/xnlinkfinder/endpoint.txt)"
    fi
else
    echo "[!] No URLs in $js/js_urls.txt to scan with xnLinkFinder"
fi
echo "[+] xnLinkFinder extraction complete"

# Step 10: Analyze beautified JS files for secrets using gf patterns
echo "[*] Creating directory for secrets: $js/secrets_from_js"
mkdir -p "$js/secrets_from_js" || { echo "[!] Error: Failed to create secrets_from_js directory"; exit 1; }
echo "[*] Changing to directory: $js/js_files_beautified for gf analysis"
cd "$js/js_files_beautified" || { echo "[!] Error: Failed to change to $js/js_files_beautified directory"; exit 1; }
echo "[*] Analyzing beautified JS files for secrets using gf patterns..."
patterns=(
    "asymmetric-keys_secrets"
    "base64"
    "aws-keys_secrets"
    "aws-s3_secrets"
    "facebook-oauth_secrets"
    "facebook-token_secrets"
    "firebase_secrets"
    "github_secrets"
    "google-keys_secrets"
    "google-oauth_secrets"
    "google-service-account_secrets"
    "google-token_secrets"
    "heroku-keys_secrets"
    "mailchimp-keys_secrets"
    "mailgun-keys_secrets"
    "paypal-token_secrets"
    "picatic-keys_secrets"
    "slack-token_secrets"
    "slack-webhook_secrets"
    "square-keys_secrets"
    "stripe-keys_secrets"
    "twilio-keys_secrets"
    "twitter-oauth_secrets"
    "twitter-token_secrets"
    "urls"
    "ip"
    "jsvar"
    "json-sec"
)

for pattern in "${patterns[@]}"; do
    echo "[*] Running gf pattern: $pattern"
    gf "$pattern" > "$(pwd)/../secrets_from_js/$pattern.txt" 2>/dev/null || echo "[!] Warning: gf pattern $pattern failed"
    echo "[+] Results saved to $js/secrets_from_js/$pattern.txt"
done

echo "[+] JS analysis complete. Results saved in $js/secrets_from_js/"
echo "[+] TruffleHog results saved in $js/trufflehog_secrets/"
echo "[+] xnLinkFinder results saved in $js/xnlinkfinder/"
if [ -s "$ERROR_LOG" ]; then
    echo "[+] Download errors logged in $ERROR_LOG"
fi
