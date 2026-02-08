#!/usr/bin/env bash
# firewall-lab install script

set -euo pipefail

echo ""
echo "  [firewall-lab] Installing..."
echo ""
echo "  This plugin creates two VMs for practicing firewall configuration:"
echo ""
echo "    1. firewall-lab-firewall  — Firewall VM"
echo "       Runs nginx, a Python HTTP server, and MariaDB"
echo "       Practice iptables, ufw, tshark, tcpdump"
echo ""
echo "    2. firewall-lab-attacker  — Attacker VM"
echo "       Equipped with nmap, curl, netcat, mariadb-client"
echo "       Probe and test the firewall VM services"
echo ""
echo "  What you will learn:"
echo "    - How to inspect and create iptables rules"
echo "    - How to configure ufw for simplified firewall management"
echo "    - How to capture and analyze traffic with tshark/tcpdump"
echo "    - How to build a production-like firewall ruleset"
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [firewall-lab] Installation complete."
echo "  Run with: qlab run firewall-lab"
