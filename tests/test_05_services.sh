#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 5 — Service Verification${RESET}"; echo ""

# 5.1 Nginx serves content
page=$(ssh_firewall "curl -s http://localhost 2>/dev/null")
assert_contains "Nginx serves content" "$page" "Firewall Lab"

# 5.2 Dashboard serves content
dashboard=$(ssh_firewall "curl -s http://localhost:9090 2>/dev/null")
assert_contains "Dashboard serves content" "$dashboard" "Internal Dashboard"

# 5.3 MariaDB accepts connections
mysql_ok=$(ssh_firewall "sudo mysql -e 'SELECT 1' 2>/dev/null" || echo "")
assert_contains "MariaDB accepts local queries" "$mysql_ok" "1"

# 5.4 Nginx content via host port (if port available)
if [[ -n "$HTTP_PORT" ]]; then
    host_page=$(curl -s --connect-timeout 3 "http://localhost:${HTTP_PORT}" 2>/dev/null || echo "")
    assert_contains "Nginx accessible via host port" "$host_page" "Firewall Lab|html"
fi

report_results "Exercise 5"
