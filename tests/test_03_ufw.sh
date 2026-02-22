#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 3 — UFW Firewall${RESET}"; echo ""

# 3.1 Allow SSH first, then enable ufw (so we don't lock ourselves out)
ssh_firewall "sudo ufw allow 22/tcp >/dev/null 2>&1; sudo ufw --force enable" >/dev/null 2>&1
sleep 2
status=$(ssh_firewall "sudo ufw status 2>/dev/null")
assert_contains "ufw is active" "$status" "Status: active"

# 3.2 Deny port 3306
ssh_firewall "sudo ufw deny 3306/tcp" >/dev/null 2>&1
ufw_rules=$(ssh_firewall "sudo ufw status numbered 2>/dev/null")
assert_contains "3306 deny rule exists" "$ufw_rules" "3306"

# 3.3 Allow port 80
ssh_firewall "sudo ufw allow 80/tcp" >/dev/null 2>&1
ufw_rules2=$(ssh_firewall "sudo ufw status 2>/dev/null")
assert_contains "80 allow rule exists" "$ufw_rules2" "80.*ALLOW"

# 3.4 Check ufw status verbose
verbose=$(ssh_firewall "sudo ufw status verbose 2>/dev/null")
assert_contains "Default incoming policy shown" "$verbose" "Default:"

# 3.5 Disable ufw (cleanup)
ssh_firewall "sudo ufw --force disable" >/dev/null 2>&1
status_disabled=$(ssh_firewall "sudo ufw status 2>/dev/null")
assert_contains "ufw disabled" "$status_disabled" "inactive"

# 3.6 Flush iptables to restore clean state
ssh_firewall "sudo iptables -F; sudo iptables -X; sudo iptables -P INPUT ACCEPT; sudo iptables -P FORWARD ACCEPT; sudo iptables -P OUTPUT ACCEPT" >/dev/null 2>&1

report_results "Exercise 3"
