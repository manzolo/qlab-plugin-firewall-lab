# firewall-lab — Firewall & Network Security Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that creates two virtual machines for practicing firewall configuration, traffic filtering, and network analysis:

| VM | SSH Port | Packages | Purpose |
|----|----------|----------|---------|
| `firewall-lab-firewall` | dynamic | `iptables`, `ufw`, `tshark`, `tcpdump`, `nginx`, `nftables`, `mariadb-server`, `python3` | Firewall VM running 3 services |
| `firewall-lab-attacker` | dynamic | `nmap`, `curl`, `netcat-openbsd`, `tcpdump`, `mariadb-client` | Probe and test firewall rules |

> **Note:** All host ports are dynamically allocated. Use `qlab ports` to see the actual port mappings.

### Services on the Firewall VM

| Service | VM Port | Host Port | Security Tier |
|---------|---------|-----------|---------------|
| nginx (web server) | 80 | dynamic | Public — learn to selectively allow |
| Python HTTP (internal dashboard) | 9090 | dynamic | Internal — learn to restrict access |
| MariaDB (database) | 3306 | dynamic | Sensitive — must always be blocked |

## Architecture

```
┌─────────────────── Host ─────────────────────┐
│                                              │
│  localhost:<port>  ──┐                       │
│  localhost:<port>  ──┼── port forwarding     │
│  localhost:<port>  ──┘  (dynamic, see        │
│                          'qlab ports')       │
│  ┌───────────────────────┐  ┌─────────────┐  │
│  │ firewall-lab-firewall │  │ firewall-lab│  │
│  │  SSH: dynamic         │  │  -attacker  │  │
│  │                       │  │ SSH: dynamic│  │
│  │  :80  nginx           │  │             │  │
│  │  :9090 Python HTTP    │  │  nmap       │  │
│  │  :3306 MariaDB        │  │  curl       │  │
│  │  iptables / ufw       │  │  netcat     │  │
│  │  tshark / tcpdump     │  │  tcpdump    │  │
│  └──────────┬────────────┘  └──────┬──────┘  │
│             │    10.0.2.2          │         │
│             └──────────────────────┘         │
│        attacker reaches firewall via         │
│        10.0.2.2:<ports> (see 'qlab ports')   │
└──────────────────────────────────────────────┘
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

## Exercises

> **New to firewalls?** See the [Step-by-Step Guide](guide.md) for complete walkthroughs with full examples and expected output.

| # | Exercise | What you'll do |
|---|----------|----------------|
| 1 | **Firewall Anatomy** | Explore services, ports, iptables defaults, and tools |
| 2 | **iptables Rules** | Add, verify, and flush INPUT chain rules |
| 3 | **UFW (Uncomplicated Firewall)** | Enable ufw, allow/deny ports, check status |
| 4 | **Traffic Capture** | Use tshark/tcpdump to capture and analyze packets |
| 5 | **Service Testing** | Test nginx, dashboard, and MariaDB content and access |
| 6 | **Attacker Reconnaissance** | Use nmap, curl, netcat from the attacker VM |

## Automated Tests

An automated test suite validates the exercises against running VMs:

```bash
# Start the lab first
qlab run firewall-lab
# Wait ~90s for cloud-init, then run all tests
qlab test firewall-lab
```

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
