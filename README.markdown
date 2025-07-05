# 3lmasr3yCon

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Version: 1.0](https://img.shields.io/badge/Version-1.0-blue.svg)

**3lmasr3yCon** is a powerful, modular reconnaissance framework designed for bug bounty hunters and security researchers. It streamlines subdomain enumeration, wayback URL collection, port scanning, vulnerability scanning, and pattern-based analysis to uncover vulnerabilities and exposed secrets. Built with flexibility in mind, it integrates three core scripts, each usable independently or together via a master script, to cater to diverse reconnaissance needs.

## Table of Contents
- [Overview](#overview)
- [Workflow Graph](#workflow-graph)
- [Why Modular Design?](#why-modular-design)
- [Scripts and Use Cases](#scripts-and-use-cases)
  - [subdomains_wayback_port_nuclei.sh](#subdomains_wayback_port_nucleish)
  - [js_analyzer.sh](#js_analyzersh)
  - [get_hit_points.sh](#get_hit_pointssh)
  - [3lmasr3yCon.sh](#3lmasr3yconsh)
  - [check_tools.sh](#check_toolssh)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Output Structure](#output-structure)
- [Performance Tips](#performance-tips)
- [Contributing](#contributing)
- [License](#license)
- [Author](#author)

## Overview

`3lmasr3yCon` automates critical reconnaissance tasks for bug bounty hunting and penetration testing:
- **Subdomain Enumeration**: Discovers subdomains using multiple tools.
- **Port Scanning**: Identifies open ports on live subdomains.
- **Wayback URL Collection**: Gathers historical URLs from the Wayback Machine.
- **Vulnerability Scanning**: Detects vulnerabilities with `nuclei`.
- **JavaScript Analysis**: Extracts and analyzes JS files for secrets.
- **URL Analysis**: Scans URLs for vulnerabilities and sensitive data using `gf` patterns.

The framework is modular, with three core scripts (`subdomains_wayback_port_nuclei.sh`, `js_analyzer.sh`, `get_hit_points.sh`) orchestrated by `3lmasr3yCon.sh`. The `check_tools.sh` script ensures all dependencies are installed.

## Workflow Graph

Below is an ASCII representation of the `3lmasr3yCon` workflow, showing how scripts interact:

```
+-------------------+       +-------------------+       +-------------------+
| Input: Domain(s)  | ----> | subdomains_       | ----> | js_analyzer.sh    |
| (-t or domains.txt|       | wayback_port_     |       | Extracts &        |
|                   |       | nuclei.sh         |       | Analyzes JS Files |
|                   |       | Enumerates Subs,  |       | for Secrets       |
|                   |       | Ports, URLs, Vulns|       +-------------------+
|                   |       |                   |       +-------------------+
|                   |       | Produces:         | ----> | get_hit_points.sh |
|                   |       | live_waymore.txt  |       | Analyzes URLs     |
|                   |       | live_subdomains.txt      | for Vulns/Secrets |
+-------------------+       +-------------------+       +-------------------+
           |                        |
           v                        v
+-------------------+       +-------------------+
| check_tools.sh    |       | 3lmasr3yCon.sh    |
| Verifies Tools &  |       | Orchestrates All  |
| gf Patterns       |       | Scripts Sequentially|
+-------------------+       +-------------------+
```

*Note*: If rendered in a GitHub-compatible viewer, this could be a Mermaid diagram (e.g., `graph TD; A[Input] --> B[subdomains_wayback_port_nuclei.sh]; B --> C[js_analyzer.sh]; B --> D[get_hit_points.sh]; A --> E[check_tools.sh]; B --> F[3lmasr3yCon.sh]`).

## Why Modular Design?

The scripts are separated to provide flexibility, performance, and customization:
- **Flexibility**: Run individual scripts for specific tasks (e.g., only subdomain enumeration or JS analysis) without executing the full workflow.
- **Performance**: Modular scripts allow users to manage resource usage on low-spec systems (e.g., AWS Lightsail with 2 GB RAM) by running resource-intensive tasks separately.
- **Customization**: Easily modify or extend individual scripts (e.g., add new `gf` patterns or tools) without affecting the entire framework.
- **Debugging**: Isolate issues to specific scripts, leveraging `Ctrl+C` handling to skip failing tools without halting the entire process.

This design caters to both beginners (using `3lmasr3yCon.sh` for an all-in-one workflow) and advanced users (running scripts standalone for targeted tasks).

## Scripts and Use Cases

### subdomains_wayback_port_nuclei.sh
**Purpose**: Performs comprehensive reconnaissance, including subdomain enumeration, port scanning, wayback URL collection, and vulnerability scanning.

**Standalone Use Cases**:
- **Subdomain Discovery**: Identify all subdomains of a target using tools like `subfinder`, `assetfinder`, `github-subdomains`, `chaos`, and `findomain`.
  ```bash
  ./subdomains_wayback_port_nuclei.sh -t example.com
  ```
- **Port Scanning**: Scan live subdomains for open ports with `naabu`.
- **Wayback URLs**: Collect historical URLs with `waymore` for further analysis.
- **Vulnerability Scanning**: Run `nuclei` to detect CVEs and misconfigurations on live subdomains.

**Why Use Alone?**: Ideal for broad reconnaissance when you need a complete picture of a target’s attack surface. Outputs like `live_subdomains.txt` and `live_waymore.txt` can be used by other scripts or tools.

### js_analyzer.sh
**Purpose**: Extracts JavaScript URLs from `live_waymore.txt`, downloads JS files, and analyzes them for secrets using `gf` patterns.

**Standalone Use Cases**:
- **JS Secret Hunting**: Analyze JS files for exposed API keys, tokens, or sensitive data (e.g., AWS keys, Firebase configs).
  ```bash
  ./js_analyzer.sh example.com/live_waymore.txt
  ```
- **Targeted JS Analysis**: Process a custom list of URLs containing JS files to check for secrets without running a full recon.
  ```bash
  cat custom_js_urls.txt | ./js_analyzer.sh
  ```

**Why Use Alone?**: Focus on client-side vulnerabilities or secrets in JS files, especially when you have a pre-existing list of URLs or want to avoid resource-heavy subdomain enumeration.

### get_hit_points.sh
**Purpose**: Analyzes URLs in `live_waymore.txt` for vulnerabilities and secrets using `gf` patterns (e.g., XSS, SSTI, S3 buckets).

**Standalone Use Cases**:
- **Vulnerability Scanning**: Identify potential vulnerabilities like XSS, SSTI, or LFI in URLs.
  ```bash
  ./get_hit_points.sh example.com/live_waymore.txt
  ```
- **Custom URL Analysis**: Scan a custom URL list for specific vulnerabilities or patterns.
  ```bash
  ./get_hit_points.sh custom_urls.txt
  ```

**Why Use Alone?**: Perfect for quick vulnerability checks on a specific set of URLs without needing subdomain or JS analysis, saving time and resources.

### 3lmasr3yCon.sh
**Purpose**: Orchestrates the above scripts for a complete reconnaissance workflow.

**Standalone Use Cases**:
- **Full Recon Workflow**: Run all scripts sequentially for a domain or list of domains.
  ```bash
  ./3lmasr3yCon.sh -t example.com
  ./3lmasr3yCon.sh domains.txt
  ```

**Why Use Alone?**: Automates the entire process for users who want a one-command solution, integrating all outputs into a cohesive structure.

### check_tools.sh
**Purpose**: Verifies that all required tools and `gf` patterns are installed, providing installation instructions if any are missing.

**Standalone Use Cases**:
- **Setup Verification**: Ensure your environment is ready before running the framework.
  ```bash
  ./check_tools.sh
  ```

**Why Use Alone?**: Essential for initial setup or troubleshooting dependency issues, especially on new systems or after updates.

## Prerequisites

### Tools
Run `check_tools.sh` to verify the following tools:
- `subfinder`: Subdomain enumeration
- `assetfinder`: Subdomain enumeration
- `github-subdomains`: GitHub-based subdomain enumeration
- `chaos`: Subdomain enumeration
- `findomain`: Subdomain enumeration
- `httpx`: Live subdomain and URL checking
- `naabu`: Port scanning (requires `libpcap-dev`)
- `waymore`: Wayback URL collection
- `nuclei`: Vulnerability scanning
- `subjs`: JavaScript URL extraction
- `gf`: Pattern-based analysis
- `curl`: File downloading
- `python3` and `pip`: For `waymore`

### API Keys
Configure API keys for:
- **GitHub Subdomains**: Obtain a Personal Access Token from [GitHub](https://github.com/settings/tokens). Set as `GITHUB_TOKEN` or edit `subdomains_wayback_port_nuclei.sh`.
- **Chaos**: Get an API key from [Chaos](https://chaos.projectdiscovery.io/). Set as `CHAOS_KEY` or edit `subdomains_wayback_port_nuclei.sh`.

**Important**: Replace placeholder API keys in `subdomains_wayback_port_nuclei.sh` before running or sharing the framework.

### gf Patterns
Install `gf` patterns from:
```bash
# 1ndianl33t/Gf-Patterns (vulnerabilities like XSS, SSTI)
git clone https://github.com/1ndianl33t/Gf-Patterns ~/.gf

# dwisiswant0/gf-secrets (secrets like AWS keys, Firebase)
git clone https://github.com/dwisiswant0/gf-secrets ~/.gf_tmp
cp ~/.gf_tmp/.gf/* ~/.gf/
rm -rf ~/.gf_tmp

# tomnomnom/gf (general patterns like base64, URLs)
git clone https://github.com/tomnomnom/gf ~/.gf_tmp
cp ~/.gf_tmp/examples/* ~/.gf/
rm -rf ~/.gf_tmp
```

Run `check_tools.sh` to verify pattern installation.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Elmasreykhaled/3lmasr3yCon.git
   cd 3lmasr3yCon
   ```

2. Make scripts executable:
   ```bash
   chmod +x *.sh
   ```

3. Run `check_tools.sh` to verify tools and patterns:
   ```bash
   ./check_tools.sh
   ```
   Follow instructions to install any missing dependencies.

4. Configure API keys in `subdomains_wayback_port_nuclei.sh` or set environment variables:
   ```bash
   export GITHUB_TOKEN="your_github_token"
   export CHAOS_KEY="your_chaos_key"
   ```

## Usage

Run the full framework:
- **Single Domain**:
  ```bash
  ./3lmasr3yCon.sh -t example.com
  ```
- **Domains File** (one domain per line):
  ```bash
  ./3lmasr3yCon.sh domains.txt
  ```

Run individual scripts for specific tasks (see [Scripts and Use Cases](#scripts-and-use-cases)).

## Output Structure

For each domain (e.g., `example.com/`):
- `subdomains/`: Subdomain enumeration results (`subfinder.txt`, `assetfinder.txt`, etc.)
- `live_subdomains.txt`: Live subdomains
- `port_scan.txt`: Open ports
- `live_waymore.txt`: Live wayback URLs
- `nuclei.txt`: Vulnerability scan results
- `js/js_urls.txt`: Extracted JavaScript URLs
- `js/js_files/`: Downloaded JavaScript files
- `js/secrets_from_js/`: Secrets found in JS files (e.g., `aws-keys_secrets.txt`)
- `hit_points/`: Vulnerability and secret analysis from URLs (e.g., `xss.txt`)

## Performance Tips
- **Low-Resource Systems**: On systems like AWS Lightsail (2 GB RAM), monitor usage with `htop` or `free -m`. Limit `nuclei` templates or `naabu` ports:
  ```bash
  ~/go/bin/nuclei -l live_subdomains.txt -t cves/ -o nuclei.txt
  sudo ~/go/bin/naabu -l live_subdomains.txt -p 80,443 -silent -o port_scan.txt
  ```
- **Parallel Processing**: Run lightweight tools (e.g., `subfinder`, `assetfinder`) in parallel:
  ```bash
  parallel -j 2 ::: "~/go/bin/subfinder -d example.com -o subdomains/subfinder.txt" "~/go/bin/assetfinder --subs-only example.com > subdomains/assetfinder.txt"
  ```
- **Error Handling**: Scripts support `Ctrl+C` to skip failing tools. Check logs for issues.

## Contributing
Submit issues or pull requests to the [GitHub repository](https://github.com/Elmasreykhaled/3lmasr3yCon). Contributions to add new tools, patterns, or optimizations are welcome!

## Author
[Elmasreykhaled](https://github.com/Elmasreykhaled)
