#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 4 — Traffic Capture${RESET}"; echo ""

# 4.1 tcpdump is available on firewall
assert "tcpdump available on firewall" ssh_firewall "which tcpdump"

# 4.2 tshark is available on firewall
assert "tshark available on firewall" ssh_firewall "which tshark"

# 4.3 tcpdump is available on attacker
assert "tcpdump available on attacker" ssh_attacker "which tcpdump"

# 4.4 Can list interfaces
interfaces=$(ssh_firewall "ip link show 2>/dev/null")
assert_contains "Network interfaces listed" "$interfaces" "ens3|eth0|enp"

# 4.5 Capture a few packets (quick test)
capture=$(ssh_firewall "sudo timeout 3 tcpdump -i any -c 1 -q 2>&1 || true")
assert_contains "tcpdump runs without error" "$capture" "listening|packet"

report_results "Exercise 4"
