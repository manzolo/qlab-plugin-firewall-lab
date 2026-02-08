# firewall-lab — Firewall & Network Security Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that creates two virtual machines for practicing firewall configuration, traffic filtering, and network analysis:

| VM | SSH Port | Packages | Purpose |
|----|----------|----------|---------|
| `firewall-lab-firewall` | 2226 | `iptables`, `ufw`, `tshark`, `tcpdump`, `nginx`, `nftables`, `mariadb-server`, `python3` | Firewall VM running 3 services |
| `firewall-lab-attacker` | 2227 | `nmap`, `curl`, `netcat-openbsd`, `tcpdump`, `mariadb-client` | Probe and test firewall rules |

### Services on the Firewall VM

| Service | VM Port | Host Port | Security Tier |
|---------|---------|-----------|---------------|
| nginx (web server) | 80 | 8180 | Public — learn to selectively allow |
| Python HTTP (internal dashboard) | 9090 | 9190 | Internal — learn to restrict access |
| MariaDB (database) | 3306 | 3360 | Sensitive — must always be blocked |

## Architecture

```
┌─────────────────── Host ────────────────────┐
│                                             │
│  localhost:8180  ──┐                        │
│  localhost:9190  ──┼── port forwarding      │
│  localhost:3360  ──┘                        │
│                                             │
│  ┌──────────────────────┐  ┌─────────────┐ │
│  │  firewall-lab-firewall│  │ firewall-lab│ │
│  │  SSH: 2226           │  │  -attacker  │ │
│  │                      │  │ SSH: 2227   │ │
│  │  :80  nginx          │  │             │ │
│  │  :9090 Python HTTP   │  │  nmap       │ │
│  │  :3306 MariaDB       │  │  curl       │ │
│  │  iptables / ufw      │  │  netcat     │ │
│  │  tshark / tcpdump    │  │  tcpdump    │ │
│  └──────────┬───────────┘  └──────┬──────┘ │
│             │    10.0.2.2         │         │
│             └─────────────────────┘         │
│        attacker reaches firewall via        │
│        10.0.2.2:8180 / :9190 / :3360       │
└─────────────────────────────────────────────┘
```

## Quick Start

```bash
qlab init
qlab install firewall-lab
qlab run firewall-lab
# Wait ~90s for boot + package installation
qlab shell firewall-lab-firewall    # connect to firewall VM
qlab shell firewall-lab-attacker    # connect to attacker VM
```

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

---

## Exercise 1: Explore Default Rules and Verify Connectivity

**On the firewall VM:**

```bash
# List current iptables rules (should be empty/ACCEPT all)
sudo iptables -L -n -v

# Verify all 3 services are running
systemctl status nginx
systemctl status internal-dashboard
systemctl status mariadb

# Test locally
curl http://localhost
curl http://localhost:9090
```

**On the attacker VM:**

```bash
# Test all 3 services are reachable through port forwarding
curl http://10.0.2.2:8180          # nginx — should return HTML
curl http://10.0.2.2:9190          # internal dashboard — should return HTML
nc -zv 10.0.2.2 3360               # MariaDB — should connect

# Scan all 3 ports at once
nmap -p 8180,9190,3360 10.0.2.2
```

---

## Exercise 2: Block HTTP with iptables

**On the firewall VM:**

```bash
# Block incoming HTTP traffic on port 80
sudo iptables -A INPUT -p tcp --dport 80 -j DROP

# Verify the rule
sudo iptables -L -n -v
```

**On the attacker VM:**

```bash
# This should now hang/timeout
curl --connect-timeout 5 http://10.0.2.2:8180

# Other services should still work
curl http://10.0.2.2:9190
nc -zv 10.0.2.2 3360
```

**On the firewall VM — remove the rule:**

```bash
sudo iptables -D INPUT -p tcp --dport 80 -j DROP
# Or flush all rules:
sudo iptables -F
```

---

## Exercise 3: Block the Database — Never Expose a DB

**On the firewall VM:**

```bash
# Block MariaDB from external access
sudo iptables -A INPUT -p tcp --dport 3306 -j DROP

# Verify the rule
sudo iptables -L -n -v
```

**On the attacker VM:**

```bash
# Database should now be unreachable
nc -zv -w 3 10.0.2.2 3360          # should timeout
mysql -h 10.0.2.2 -P 3360 -u root  # should fail

# Web services should still work
curl http://10.0.2.2:8180
curl http://10.0.2.2:9190
```

**Lesson:** Databases should never be exposed to the public. Always block database ports at the firewall level.

---

## Exercise 4: Use ufw Instead of iptables

**On the firewall VM:**

```bash
# First, flush iptables rules
sudo iptables -F

# Enable ufw (default: deny incoming, allow outgoing)
sudo ufw --force enable

# Allow SSH (important! don't lock yourself out)
sudo ufw allow 22/tcp

# Block HTTP (web server)
sudo ufw deny 80/tcp

# Block MariaDB
sudo ufw deny 3306/tcp

# Allow internal dashboard (restricted allow)
sudo ufw allow 9090/tcp

# Check the status
sudo ufw status verbose
```

**On the attacker VM:**

```bash
curl --connect-timeout 5 http://10.0.2.2:8180    # blocked
curl http://10.0.2.2:9190                          # allowed
nc -zv -w 3 10.0.2.2 3360                          # blocked
```

**Reset ufw:**

```bash
sudo ufw --force reset
```

---

## Exercise 5: Capture Traffic with tshark

**On the firewall VM (terminal 1):**

```bash
# Capture HTTP traffic on port 80
sudo tshark -i ens3 -f "tcp port 80" -c 20
```

**On the attacker VM (terminal 2):**

```bash
# Generate traffic to the web server
curl http://10.0.2.2:8180
curl http://10.0.2.2:8180
curl http://10.0.2.2:8180
```

**Back on the firewall VM — observe the captured packets.**

Try other captures:

```bash
# Capture all traffic from the attacker
sudo tshark -i ens3 -c 30

# Capture only SYN packets (connection attempts)
sudo tshark -i ens3 -f "tcp[tcpflags] & tcp-syn != 0" -c 10

# Capture database connection attempts
sudo tshark -i ens3 -f "tcp port 3306" -c 10

# Save capture to file for later analysis
sudo tshark -i ens3 -f "tcp port 80" -c 50 -w /tmp/capture.pcap
sudo tshark -r /tmp/capture.pcap    # read back
```

---

## Exercise 6: Build a Production-Like Ruleset

**On the firewall VM:**

```bash
# Flush all existing rules
sudo iptables -F
sudo iptables -X

# Set default policies: drop everything incoming
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Allow loopback (local traffic)
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow established/related connections (responses to outgoing traffic)
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (port 22) — keep access to the VM
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP (port 80) — public web server
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Allow internal dashboard (port 9090) — restricted
# In production, you would restrict by source IP
sudo iptables -A INPUT -p tcp --dport 9090 -j ACCEPT

# Block MariaDB (port 3306) — explicitly drop and log
sudo iptables -A INPUT -p tcp --dport 3306 -j LOG --log-prefix "BLOCKED-DB: "
sudo iptables -A INPUT -p tcp --dport 3306 -j DROP

# Log all other dropped packets
sudo iptables -A INPUT -j LOG --log-prefix "DROPPED: " --log-level 4

# Verify the complete ruleset
sudo iptables -L -n -v --line-numbers
```

**On the attacker VM:**

```bash
# Test the complete ruleset
curl http://10.0.2.2:8180                          # allowed (web)
curl http://10.0.2.2:9190                          # allowed (internal)
nc -zv -w 3 10.0.2.2 3360                          # blocked (database)
nmap -p 8180,9190,3360 10.0.2.2                    # scan all ports
```

**On the firewall VM — check the logs:**

```bash
# View blocked connection attempts
sudo dmesg | grep "BLOCKED-DB"
sudo dmesg | grep "DROPPED"
```

---

## Managing VMs

```bash
qlab status                        # show all running VMs
qlab stop firewall-lab             # stop both VMs
qlab stop firewall-lab-firewall    # stop only firewall VM
qlab stop firewall-lab-attacker    # stop only attacker VM
qlab log firewall-lab-firewall     # view firewall VM boot log
qlab log firewall-lab-attacker     # view attacker VM boot log
qlab uninstall firewall-lab        # stop all VMs and remove plugin
```

## Reset

To start the lab from scratch:

```bash
qlab stop firewall-lab
qlab run firewall-lab
```

This recreates the overlay disks and cloud-init configuration, giving you a fresh environment.

## License

MIT
