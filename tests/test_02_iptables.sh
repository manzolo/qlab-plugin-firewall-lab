#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 2 — iptables Rules${RESET}"; echo ""

# 2.1 List current iptables rules
rules=$(ssh_firewall "sudo iptables -L -n 2>/dev/null")
assert_contains "iptables rules listed" "$rules" "Chain INPUT"

# 2.2 Add a DROP rule for port 9090
ssh_firewall "sudo iptables -A INPUT -p tcp --dport 9090 -j DROP" >/dev/null 2>&1
rules_after=$(ssh_firewall "sudo iptables -L INPUT -n 2>/dev/null")
assert_contains "DROP rule added for 9090" "$rules_after" "9090.*DROP|DROP.*9090"

# 2.3 Verify dashboard is blocked locally
blocked=$(ssh_firewall "curl -s --connect-timeout 2 http://localhost:9090 2>/dev/null" || echo "blocked")
assert_contains "Dashboard blocked by iptables" "$blocked" "blocked"

# 2.4 Flush iptables rules
ssh_firewall "sudo iptables -F" >/dev/null 2>&1
rules_flushed=$(ssh_firewall "sudo iptables -L INPUT -n 2>/dev/null")
assert_not_contains "Rules flushed" "$rules_flushed" "9090"

# 2.5 Dashboard accessible again after flush
page=$(ssh_firewall "curl -s --connect-timeout 3 http://localhost:9090 2>/dev/null" || echo "")
assert_contains "Dashboard accessible after flush" "$page" "Internal Dashboard|html"

report_results "Exercise 2"
