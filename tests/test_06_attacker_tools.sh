#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 6 — Attacker Tools${RESET}"; echo ""

# 6.1 nmap is installed
assert "nmap installed" ssh_attacker "which nmap"

# 6.2 curl is installed
assert "curl installed" ssh_attacker "which curl"

# 6.3 netcat is installed
assert "netcat installed" ssh_attacker "which nc"

# 6.4 mariadb-client is installed
assert "mariadb-client installed" ssh_attacker "which mariadb || which mysql"

# 6.5 tcpdump is installed
assert "tcpdump installed" ssh_attacker "which tcpdump"

# 6.6 net-tools installed
assert "net-tools installed" ssh_attacker "which netstat || which ifconfig"

report_results "Exercise 6"
