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

# Define the js directory
js="js"

# Step 1: Create main js directory
echo "[*] Creating main directory: $js"
mkdir -p "$js" || { echo "[!] Error: Failed to create directory $js"; exit 1; }

# Step 2: Extract JS URLs using subjs
echo "[*] Extracting JS URLs using subjs..."
cat "$WAYMORE_FILE" | subjs > "$js/js_subjs.txt" || { echo "[!] Error: Failed to run subjs"; exit 1; }
echo "[+] Saved subjs output to $js/js_subjs.txt"

# Step 3: Extract JS URLs using grep
echo "[*] Extracting JS URLs using grep..."
cat "$WAYMORE_FILE" | grep -E '\.js(\?.*)?$' > "$js/js_waymore.txt" || { echo "[!] Error: Failed to grep .js URLs"; exit 1; }
echo "[+] Saved grep output to $js/js_waymore.txt"

# Step 4: Merge results, remove duplicates, and clean up temporary files
echo "[*] Merging and deduplicating JS URLs..."
cat "$js/js_subjs.txt" "$js/js_waymore.txt" | sort -u > "$js/js_urls.txt" || { echo "[!] Error: Failed to merge and sort URLs"; exit 1; }
echo "[+] Merged URLs saved to $js/js_urls.txt"
echo "[*] Cleaning up temporary files..."
rm "$js/js_subjs.txt" "$js/js_waymore.txt" || { echo "[!] Error: Failed to remove temporary files"; exit 1; }
echo "[+] Temporary files removed"

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
        continue
    fi
    # Generate a safe filename from URL
    filename=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g').js
    echo "[*] Downloading $url to $js/js_files/$filename"
    # Download with retries, user-agent, and timeout
    curl -s -L --fail --retry 3 --retry-delay 2 --connect-timeout 10 \
         -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
         "$url" -o "$js/js_files/$filename" || echo "[!] Failed to download $url (check network or server response)"
    # Small delay to avoid rate limiting
    sleep 1
done < "$js/js_urls.txt"
echo "[+] JS files download complete"

# Step 6: Analyze JS files for secrets using gf patterns
echo "[*] Creating directory for secrets: $js/secrets_from_js"
mkdir -p "$js/secrets_from_js" || { echo "[!] Error: Failed to create secrets_from_js directory"; exit 1; }
echo "[*] Changing to directory: $js/js_files for gf analysis"
cd "$js/js_files" || { echo "[!] Error: Failed to change to $js/js_files directory"; exit 1; }
echo "[*] Analyzing JS files for secrets using gf patterns..."
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
