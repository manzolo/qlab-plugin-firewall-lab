# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a QLab plugin that creates a network security lab environment with two interconnected virtual machines for practicing firewall configuration, traffic filtering, and network analysis.

## Architecture

The firewall-lab plugin creates two VMs:
1. **firewall-lab-firewall** - Firewall VM running:
   - nginx (web server on port 80)
   - Python HTTP server (internal dashboard on port 9090)
   - MariaDB (database on port 3306)
   - Tools: iptables, ufw, tshark, tcpdump, nftables, net-tools

2. **firewall-lab-attacker** - Attacker VM equipped with:
   - nmap, curl, netcat, tcpdump
   - mariadb-client
   - Tools for probing and testing firewall VM services

## Key Files and Structure

- `plugin.conf` - Plugin metadata
- `install.sh` - Installation script that checks dependencies
- `run.sh` - Main execution script that:
  - Downloads Ubuntu cloud image
  - Creates cloud-init configurations for both VMs
  - Generates ISOs with cloud-init data
  - Creates overlay disks for VMs
  - Starts both VMs with port forwarding

## How to Develop and Work with This Codebase

### Quick Start
```bash
qlab init
qlab install firewall-lab
qlab run firewall-lab
# Wait ~90s for boot + package installation
qlab shell firewall-lab-firewall    # connect to firewall VM
qlab shell firewall-lab-attacker    # connect to attacker VM
```

### Main Development Tasks

1. **Understanding the VM setup**: The run.sh script orchestrates the entire setup process, from downloading cloud images to starting VMs with proper port forwarding.

2. **Cloud-init configurations**: Both VMs use cloud-init for initial setup:
   - Firewall VM: Sets up services (nginx, Python HTTP server, MariaDB) and firewall tools
   - Attacker VM: Installs tools for network probing and testing

3. **Network configuration**: The setup uses QEMU's hostfwd (port forwarding) to expose VM services to the host:
   - localhost:<dynamic> → firewall VM port 80 (nginx)
   - localhost:<dynamic> → firewall VM port 9090 (Python HTTP)
   - localhost:<dynamic> → firewall VM port 3306 (MariaDB)
   - All host ports are dynamically allocated — use `qlab ports` to see actual mappings

4. **Security exercises**: The README contains detailed exercises for:
   - Exploring default rules
   - Blocking HTTP with iptables
   - Blocking database access
   - Using ufw instead of iptables
   - Capturing traffic with tshark
   - Building production-like rulesets

### Common Commands

- `qlab run firewall-lab` - Start the lab environment
- `qlab shell firewall-lab-firewall` - Connect to firewall VM
- `qlab shell firewall-lab-attacker` - Connect to attacker VM
- `qlab stop firewall-lab` - Stop all VMs
- `qlab log firewall-lab-firewall` - View firewall VM boot log

### Key Technologies

- QEMU for virtualization
- Cloud-init for VM configuration
- Ubuntu minimal cloud images
- iptables and ufw for firewall management
- tshark/tcpdump for packet capture
- Port forwarding via QEMU's hostfwd

### Learning Objectives

This lab teaches network security concepts including:
- How to inspect and create iptables rules
- How to configure ufw for simplified firewall management
- How to capture and analyze traffic with tshark/tcpdump
- How to build a production-like firewall ruleset
- How to block database access at the firewall level