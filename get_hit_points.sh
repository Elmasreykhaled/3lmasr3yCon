#!/bin/bash

# Check if a path to live_waymore.txt is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <path_to_live_waymore.txt>"
  exit 1
fi

# Store the input path
WAYMORE_PATH="$PWD/$1"

# Check if live_waymore.txt exists
if [ ! -f "$WAYMORE_PATH" ]; then
  echo "Error: $WAYMORE_PATH does not exist"
  exit 1
fi

# Create hit_points directory if it doesn't exist
mkdir -p hit_points

# Change to hit_points directory
cd hit_points || exit 1

# Copy live_waymore.txt to hit_points
cp "$WAYMORE_PATH" live_waymore.txt || {
  echo "Error: Failed to copy $WAYMORE_PATH"
  exit 1
}

# List of patterns
patterns=(
  "base64"
  "cors"
  "debug-pages"
  "debug_logic"
  "firebase"
  "fw"
  "go-functions"
  "http-auth"
  "idor"
  "img-traversal"
  "interestingEXT"
  "interestingparams"
  "lfi"
  "meg-headers"
  "php-curl"
  "php-errors"
  "php-serialized"
  "php-sinks"
  "php-sources"
  "rce"
  "redirect"
  "s3-buckets"
  "sec"
  "servers"
  "ssti"
  "strings"
  "takeovers"
  "upload-fields"
  "xss"
)

# Run gf for each pattern
for pattern in "${patterns[@]}"; do
  echo "Running gf for $pattern..."
  gf "$pattern" live_waymore.txt > "${pattern}.txt" || {
    echo "Error: gf failed for $pattern"
  }
done

# Remove live_waymore.txt from hit_points
rm -f live_waymore.txt || {
  echo "Error: Failed to remove live_waymore.txt"
}

echo "Done! Output files are in $(pwd)"
