# Firewall Lab — Step-by-Step Guide

This lab teaches Linux firewall concepts using **iptables**, **ufw**, and traffic capture tools (**tshark**, **tcpdump**). You will configure rules to allow and block network traffic between two VMs.

## Prerequisites

Start the lab:

```bash
qlab run firewall-lab
```

Wait ~90 seconds for both VMs to boot and install packages. Connect to each VM:

```bash
# Terminal 1 — Firewall VM (has services + firewall tools)
qlab shell firewall-lab-firewall

# Terminal 2 — Attacker VM (has probing tools)
qlab shell firewall-lab-attacker
```

## Architecture

```
┌─────────────────────┐      ┌─────────────────────┐
│  firewall-lab-      │      │  firewall-lab-       │
│  firewall           │      │  attacker            │
│                     │      │                      │
│  Services:          │      │  Tools:              │
│   nginx     :80     │      │   nmap               │
│   dashboard :9090   │      │   curl               │
│   MariaDB   :3306   │      │   netcat             │
│                     │      │   mariadb-client      │
│  Firewall tools:    │      │   tcpdump            │
│   iptables, ufw     │      │                      │
│   tshark, tcpdump   │      │                      │
└─────────────────────┘      └──────────────────────┘
```

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

---

## Exercise 01 — Firewall Anatomy

**Goal:** Understand what services are running and what tools are available.

**Why:** Before configuring firewall rules, you need to know what services are exposed and which ports they use. This is the foundation of network security.

### 1.1 Check running services

On the **firewall VM**:

```bash
systemctl is-active nginx
systemctl is-active mariadb
systemctl is-active internal-dashboard
```

**Expected output:**

```
active
active
active
```

### 1.2 Check listening ports

```bash
ss -tlnp
```

You should see ports 80 (nginx), 9090 (dashboard), and 3306 (MariaDB) listening.

### 1.3 Verify firewall tools

```bash
which iptables
which ufw
which tshark
which tcpdump
```

### 1.4 Check attacker tools

On the **attacker VM**:

```bash
which nmap
which curl
which nc
which mysql
```

**Verification:** All four tools are installed and available.

---

## Exercise 02 — iptables Rules

**Goal:** Create, inspect, and manage iptables firewall rules.

**Why:** iptables is the traditional Linux firewall. Understanding it gives you fine-grained control over network traffic. Even when using ufw, it translates to iptables rules underneath.

### 2.1 List current rules

On the **firewall VM**:

```bash
sudo iptables -L -n -v
```

**Expected output:** Shows Chain INPUT, FORWARD, OUTPUT with policy ACCEPT and no rules (clean state).

### 2.2 Block port 9090 (dashboard)

```bash
sudo iptables -A INPUT -p tcp --dport 9090 -j DROP
```

### 2.3 Verify the rule

```bash
sudo iptables -L INPUT -n --line-numbers
```

**Expected output:**

```
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    DROP       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:9090
```

### 2.4 Test the block

```bash
curl --connect-timeout 3 http://localhost:9090
```

This should timeout — the dashboard is now blocked.

### 2.5 Flush all rules (restore access)

```bash
sudo iptables -F
```

Verify dashboard is accessible again:

```bash
curl -s http://localhost:9090 | head -5
```

---

## Exercise 03 — UFW (Uncomplicated Firewall)

**Goal:** Use ufw for simplified firewall management.

**Why:** ufw provides a user-friendly interface to iptables. It is the default firewall tool on Ubuntu and is easier to use for common tasks.

### 3.1 Allow SSH and enable ufw

On the **firewall VM**:

```bash
sudo ufw allow 22/tcp       # Always allow SSH BEFORE enabling!
sudo ufw --force enable
```

### 3.2 Set rules

```bash
sudo ufw allow 80/tcp       # Allow web server
sudo ufw deny 3306/tcp      # Block database
sudo ufw deny 9090/tcp      # Block dashboard
```

### 3.3 Check status

```bash
sudo ufw status numbered
```

**Expected output:**

```
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 80/tcp                     ALLOW IN    Anywhere
[ 3] 3306/tcp                   DENY IN     Anywhere
[ 4] 9090/tcp                   DENY IN     Anywhere
```

### 3.4 Delete a rule

```bash
sudo ufw delete deny 9090/tcp
```

### 3.5 Disable ufw (cleanup)

```bash
sudo ufw --force disable
sudo iptables -F
```

---

## Exercise 04 — Traffic Capture

**Goal:** Capture and analyze network traffic with tcpdump and tshark.

**Why:** Packet capture is essential for debugging network issues and verifying that firewall rules work as expected. It lets you see exactly what traffic flows through the system.

### 4.1 Capture HTTP traffic with tcpdump

On the **firewall VM** (in one terminal):

```bash
sudo tcpdump -i any -n port 80 -c 5
```

In another terminal, generate traffic:

```bash
curl -s http://localhost >/dev/null
```

**Expected output:** You should see TCP packets on port 80.

### 4.2 Capture with tshark

```bash
sudo tshark -i any -f "tcp port 80" -c 5
```

### 4.3 Filter by protocol

```bash
sudo tcpdump -i any -n -c 10 tcp
```

---

## Exercise 05 — Service Testing

**Goal:** Verify that services are accessible and test connectivity.

**Why:** After configuring firewall rules, you need to verify which services are accessible and which are blocked. This validates your firewall configuration.

### 5.1 Test nginx

On the **firewall VM**:

```bash
curl -s http://localhost | head -3
```

**Expected output:**

```html
<!DOCTYPE html>
<html>
<head><title>Firewall Lab</title></head>
```

### 5.2 Test dashboard

```bash
curl -s http://localhost:9090 | head -3
```

### 5.3 Test MariaDB

```bash
sudo mysql -e "SELECT 'MariaDB is working' AS status"
```

**Expected output:**

```
+--------------------+
| status             |
+--------------------+
| MariaDB is working |
+--------------------+
```

---

## Exercise 06 — Attacker Reconnaissance

**Goal:** Use the attacker VM to probe the firewall VM services.

**Why:** Understanding attacker techniques helps you build better defenses. Port scanning and service probing are fundamental security testing skills.

### 6.1 Tools available

On the **attacker VM**:

```bash
which nmap curl nc mysql
```

### 6.2 Network tools

```bash
ip addr show
netstat -rn
```

---

## Troubleshooting

### Locked out of SSH

If you accidentally blocked SSH with ufw/iptables, stop and restart the VMs:

```bash
qlab stop firewall-lab
qlab run firewall-lab
```

### Services not running

```bash
sudo systemctl status nginx mariadb internal-dashboard
sudo journalctl -u nginx --no-pager -n 20
```

### ufw rules not taking effect

```bash
sudo ufw --force disable
sudo iptables -F
sudo ufw --force enable
```

### Packages not installed

Wait for cloud-init to complete:

```bash
cloud-init status --wait
```
