#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 1 — Firewall Anatomy${RESET}"; echo ""

# 1.1 Services running on firewall VM
status_nginx=$(ssh_firewall "systemctl is-active nginx 2>/dev/null" || echo "unknown")
assert_contains "nginx is active" "$status_nginx" "active"

status_mariadb=$(ssh_firewall "systemctl is-active mariadb 2>/dev/null" || echo "unknown")
assert_contains "MariaDB is active" "$status_mariadb" "active"

# 1.2 Python dashboard service
status_dashboard=$(ssh_firewall "systemctl is-active internal-dashboard 2>/dev/null" || echo "unknown")
assert_contains "Internal dashboard is active" "$status_dashboard" "active"

# 1.3 Ports are listening
ports=$(ssh_firewall "ss -tlnp 2>/dev/null")
assert_contains "Port 80 listening" "$ports" ":80"
assert_contains "Port 9090 listening" "$ports" ":9090"
assert_contains "Port 3306 listening" "$ports" ":3306"

# 1.4 iptables is available
assert "iptables is installed" ssh_firewall "which iptables"

# 1.5 ufw is available
assert "ufw is installed" ssh_firewall "which ufw"

# 1.6 tshark is available
assert "tshark is installed" ssh_firewall "which tshark"

# 1.7 Attacker has nmap
assert "nmap is installed on attacker" ssh_attacker "which nmap"

# 1.8 Attacker has curl
assert "curl is installed on attacker" ssh_attacker "which curl"

report_results "Exercise 1"
