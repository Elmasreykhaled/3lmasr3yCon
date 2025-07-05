#!/bin/bash

echo "[*] Checking for required tools for 3lmasr3yCon framework..."

# List of required tools
TOOLS=(
    "subfinder:go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "assetfinder:go install github.com/tomnomnom/assetfinder@latest"
    "github-subdomains:go install github.com/gwen001/github-subdomains@latest"
    "chaos:go install github.com/projectdiscovery/chaos-client/cmd/chaos@latest"
    "findomain:Follow installation instructions at https://github.com/Findomain/Findomain#installation"
    "httpx:go install github.com/projectdiscovery/httpx/cmd/httpx@latest"
    "naabu:go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest && sudo apt-get install -y libpcap-dev"
    "waymore:python3 -m pip install waymore"
    "nuclei:go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    "subjs:go install github.com/lc/subjs@latest"
    "gf:go install github.com/tomnomnom/gf@latest && source ~/.profile"
    "curl:sudo apt-get install -y curl"
)

# Flag to track missing tools
MISSING_TOOLS=0

# Check each tool
for tool in "${TOOLS[@]}"; do
    TOOL_NAME=$(echo "$tool" | cut -d':' -f1)
    INSTALL_INSTRUCTIONS=$(echo "$tool" | cut -d':' -f2-)

    # Check if tool is installed
    if command -v "$TOOL_NAME" >/dev/null 2>&1; then
        echo "[+] $TOOL_NAME is installed"
    else
        echo "[!] $TOOL_NAME is not installed. Install it using:"
        echo "    $INSTALL_INSTRUCTIONS"
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
    fi
done

# Check for libpcap-dev (required for naabu)
if ! dpkg -s libpcap-dev >/dev/null 2>&1; then
    echo "[!] libpcap-dev is not installed. Install it using:"
    echo "    sudo apt-get install -y libpcap-dev"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
fi

# Check for Python (required for waymore)
if ! command -v python3 >/dev/null 2>&1; then
    echo "[!] python3 is not installed. Install it using:"
    echo "    sudo apt-get install -y python3 python3-pip"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
fi

# Check for gf patterns directory and specific pattern sources
if [ ! -d ~/.gf ]; then
    echo "[!] gf patterns directory (~/.gf) not found. Install gf patterns from the following sources:"
    echo "    git clone https://github.com/1ndianl33t/Gf-Patterns ~/.gf"
    echo "    git clone https://github.com/dwisiswant0/gf-secrets ~/.gf_tmp && cp ~/.gf_tmp/.gf/* ~/.gf/ && rm -rf ~/.gf_tmp"
    echo "    git clone https://github.com/tomnomnom/gf ~/.gf_tmp && cp ~/.gf_tmp/examples/* ~/.gf/ && rm -rf ~/.gf_tmp"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
else
    echo "[+] gf patterns directory found"
    # Check for at least one pattern file from each source
    if ! ls ~/.gf/* 2>/dev/null | grep -q "Gf-Patterns"; then
        echo "[!] Missing patterns from 1ndianl33t/Gf-Patterns. Install using:"
        echo "    git clone https://github.com/1ndianl33t/Gf-Patterns ~/.gf"
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
    fi
    if ! ls ~/.gf/* 2>/dev/null | grep -q "gf-secrets"; then
        echo "[!] Missing patterns from dwisiswant0/gf-secrets. Install using:"
        echo "    git clone https://github.com/dwisiswant0/gf-secrets ~/.gf_tmp && cp ~/.gf_tmp/.gf/* ~/.gf/ && rm -rf ~/.gf_tmp"
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
    fi
    if ! ls ~/.gf/* 2>/dev/null | grep -q "tomnomnom"; then
        echo "[!] Missing patterns from tomnomnom/gf. Install using:"
        echo "    git clone https://github.com/tomnomnom/gf ~/.gf_tmp && cp ~/.gf_tmp/examples/* ~/.gf/ && rm -rf ~/.gf_tmp"
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
    fi
fi

# Summary
if [ "$MISSING_TOOLS" -eq 0 ]; then
    echo "[+] All required tools and dependencies are installed!"
else
    echo "[!] $MISSING_TOOLS tools or dependencies are missing. Please install them before running the 3lmasr3yCon framework."
    exit 1
fi

echo "[*] Tool check complete. You are ready to run 3lmasr3yCon!"