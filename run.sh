#!/usr/bin/env bash
# firewall-lab run script — boots two VMs for iptables, ufw, and Wireshark labs

set -euo pipefail

PLUGIN_NAME="firewall-lab"
FIREWALL_VM="firewall-lab-firewall"
ATTACKER_VM="firewall-lab-attacker"

echo "============================================="
echo "  firewall-lab: Firewall & Network Security"
echo "============================================="
echo ""
echo "  This lab creates two VMs:"
echo ""
echo "    1. $FIREWALL_VM"
echo "       Runs 3 services: nginx (:80), Python HTTP (:9090), MariaDB (:3306)"
echo "       Practice iptables, ufw, tshark, tcpdump"
echo ""
echo "    2. $ATTACKER_VM"
echo "       Equipped with nmap, curl, netcat, mariadb-client"
echo "       Probe and test the firewall VM services"
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi

for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY="${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY 1024)}"

# Ensure directories exist
mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# =============================================
# Step 1: Download cloud image (shared by both VMs)
# =============================================
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  Both VMs will share the same base image via overlay disks."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# =============================================
# Step 2: Cloud-init configurations
# =============================================
info "Step 2: Cloud-init configuration for both VMs"
echo ""

# --- Firewall VM cloud-init ---
info "Creating cloud-init for $FIREWALL_VM..."

cat > "$LAB_DIR/user-data-firewall" <<'USERDATA'
#cloud-config
hostname: firewall-lab-firewall
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
package_update: true
packages:
  - ufw
  - iptables
  - tshark
  - tcpdump
  - nginx
  - nftables
  - net-tools
  - mariadb-server
  - python3
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mfirewall-lab-firewall\033[0m — \033[1mFirewall & Network Security Lab\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mObjectives:\033[0m
          • inspect and create iptables rules
          • configure ufw for simplified management
          • capture traffic with tshark / tcpdump

        \033[1;33mServices running on this VM:\033[0m
          \033[0;32mPort 80\033[0m    nginx          (public web server)
          \033[0;32mPort 9090\033[0m  Python HTTP    (internal dashboard)
          \033[0;32mPort 3306\033[0m  MariaDB        (database — block this!)

        \033[1;33mUseful commands:\033[0m
          \033[0;32msudo iptables -L -n -v\033[0m              list current rules
          \033[0;32msudo iptables -A INPUT -p tcp --dport 80 -j DROP\033[0m
          \033[0;32msudo iptables -F\033[0m                    flush all rules
          \033[0;32msudo ufw enable\033[0m                     enable ufw
          \033[0;32msudo ufw deny 80/tcp\033[0m                block HTTP
          \033[0;32msudo tshark -i ens3 -f "tcp port 80"\033[0m  capture traffic

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

  - path: /var/www/html/index.html
    content: |
      <!DOCTYPE html>
      <html>
      <head><title>Firewall Lab</title></head>
      <body>
      <h1>Firewall Lab - Nginx Web Server</h1>
      <p>This is the public web server running on the firewall VM.</p>
      <p>Try blocking access to this page using iptables or ufw!</p>
      </body>
      </html>
  - path: /etc/systemd/system/internal-dashboard.service
    content: |
      [Unit]
      Description=Internal Dashboard (Python HTTP Server on port 9090)
      After=network.target
      [Service]
      Type=simple
      ExecStart=/usr/bin/python3 -m http.server 9090 --directory /srv/dashboard
      Restart=always
      [Install]
      WantedBy=multi-user.target
  - path: /srv/dashboard/index.html
    content: |
      <!DOCTYPE html>
      <html>
      <head><title>Internal Dashboard</title></head>
      <body>
      <h1>Internal Dashboard (port 9090)</h1>
      <p>This is an internal application — it should be restricted!</p>
      </body>
      </html>
runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - export DEBIAN_FRONTEND=noninteractive
  - systemctl enable nginx
  - systemctl start nginx
  - mkdir -p /srv/dashboard
  - systemctl daemon-reload
  - systemctl enable internal-dashboard
  - systemctl start internal-dashboard
  - sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
  - systemctl restart mariadb
  - echo "=== firewall-lab-firewall VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-firewall"

cat > "$LAB_DIR/meta-data-firewall" <<METADATA
instance-id: ${FIREWALL_VM}-001
local-hostname: ${FIREWALL_VM}
METADATA

success "Created cloud-init for $FIREWALL_VM"

# --- Attacker VM cloud-init ---
info "Creating cloud-init for $ATTACKER_VM..."

cat > "$LAB_DIR/user-data-attacker" <<'USERDATA'
#cloud-config
hostname: firewall-lab-attacker
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
package_update: true
packages:
  - nmap
  - curl
  - netcat-openbsd
  - tcpdump
  - net-tools
  - iputils-ping
  - mariadb-client
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;31mfirewall-lab-attacker\033[0m — \033[1mAttacker / Probe VM\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mRole:\033[0m  Probe the firewall VM services to test rules

        \033[1;33mTarget services (on the firewall VM):\033[0m
          \033[0;32m10.0.2.2:8180\033[0m   nginx          (public web)
          \033[0;32m10.0.2.2:9190\033[0m   Python HTTP    (internal dashboard)
          \033[0;32m10.0.2.2:3360\033[0m   MariaDB        (database)

        \033[1;33mUseful commands:\033[0m
          \033[0;32mcurl http://10.0.2.2:8180\033[0m            test web server
          \033[0;32mcurl http://10.0.2.2:9190\033[0m            test internal app
          \033[0;32mnc -zv 10.0.2.2 3360\033[0m                test database port
          \033[0;32mmysql -h 10.0.2.2 -P 3360 -u root\033[0m   connect to MariaDB
          \033[0;32mnmap -p 80,9090,3306 10.0.2.2\033[0m       scan all 3 ports
          \033[0;32msudo tcpdump -i ens3 -n\033[0m              capture traffic

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - echo "=== firewall-lab-attacker VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-attacker"

cat > "$LAB_DIR/meta-data-attacker" <<METADATA
instance-id: ${ATTACKER_VM}-001
local-hostname: ${ATTACKER_VM}
METADATA

success "Created cloud-init for $ATTACKER_VM"
echo ""

# =============================================
# Step 3: Generate cloud-init ISOs
# =============================================
info "Step 3: Cloud-init ISOs"
echo ""
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}

CIDATA_FIREWALL="$LAB_DIR/cidata-firewall.iso"
genisoimage -output "$CIDATA_FIREWALL" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-firewall" "meta-data=$LAB_DIR/meta-data-firewall" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_FIREWALL"

CIDATA_ATTACKER="$LAB_DIR/cidata-attacker.iso"
genisoimage -output "$CIDATA_ATTACKER" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-attacker" "meta-data=$LAB_DIR/meta-data-attacker" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_ATTACKER"
echo ""

# =============================================
# Step 4: Create overlay disks
# =============================================
info "Step 4: Overlay disks"
echo ""
echo "  Each VM gets its own overlay disk (copy-on-write) so the"
echo "  base cloud image is never modified."
echo ""

OVERLAY_FIREWALL="$LAB_DIR/${FIREWALL_VM}-disk.qcow2"
if [[ -f "$OVERLAY_FIREWALL" ]]; then rm -f "$OVERLAY_FIREWALL"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_FIREWALL" "${QLAB_DISK_SIZE:-}" || {
    error "Failed to create overlay disk for firewall VM."
    exit 1
}

OVERLAY_ATTACKER="$LAB_DIR/${ATTACKER_VM}-disk.qcow2"
if [[ -f "$OVERLAY_ATTACKER" ]]; then rm -f "$OVERLAY_ATTACKER"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_ATTACKER" "${QLAB_DISK_SIZE:-}" || {
    error "Failed to create overlay disk for attacker VM."
    exit 1
}
echo ""

# =============================================
# Step 5: Start both VMs
# =============================================
info "Step 5: Starting VMs"
echo ""

# Multi-VM: resource check, cleanup trap, rollback on failure
MEMORY_TOTAL=$(( MEMORY * 2 ))
check_host_resources "$MEMORY_TOTAL" 2
declare -a STARTED_VMS=()
register_vm_cleanup STARTED_VMS

info "Starting $FIREWALL_VM..."
start_vm_or_fail STARTED_VMS "$OVERLAY_FIREWALL" "$CIDATA_FIREWALL" "$MEMORY" "$FIREWALL_VM" auto \
    "hostfwd=tcp::0-:80" \
    "hostfwd=tcp::0-:9090" \
    "hostfwd=tcp::0-:3306" || exit 1
FIREWALL_SSH_PORT="$LAST_SSH_PORT"

# Read the dynamically allocated service ports from .ports file
FW_HTTP_PORT=""
FW_COCKPIT_PORT=""
FW_MYSQL_PORT=""
if [[ -f "$STATE_DIR/${FIREWALL_VM}.ports" ]]; then
    FW_HTTP_PORT=$(grep ':80$' "$STATE_DIR/${FIREWALL_VM}.ports" | head -1 | cut -d: -f2)
    FW_COCKPIT_PORT=$(grep ':9090$' "$STATE_DIR/${FIREWALL_VM}.ports" | head -1 | cut -d: -f2)
    FW_MYSQL_PORT=$(grep ':3306$' "$STATE_DIR/${FIREWALL_VM}.ports" | head -1 | cut -d: -f2)
fi

echo ""

info "Starting $ATTACKER_VM..."
start_vm_or_fail STARTED_VMS "$OVERLAY_ATTACKER" "$CIDATA_ATTACKER" "$MEMORY" "$ATTACKER_VM" auto || exit 1
ATTACKER_SSH_PORT="$LAST_SSH_PORT"

# Successful start — disable cleanup trap
trap - EXIT

echo ""
echo "============================================="
echo "  firewall-lab: Both VMs are booting"
echo "============================================="
echo ""
echo "  Firewall VM:"
echo "    SSH:   qlab shell $FIREWALL_VM"
echo "    Log:   qlab log $FIREWALL_VM"
if [[ -n "$FW_HTTP_PORT" ]]; then
echo "    HTTP:  http://localhost:${FW_HTTP_PORT}"
echo "    Dashboard: http://localhost:${FW_COCKPIT_PORT}"
echo "    MySQL: localhost:${FW_MYSQL_PORT}"
else
echo "    Services: check ports with 'qlab ports'"
fi
echo ""
echo "  Attacker VM:"
echo "    SSH:   qlab shell $ATTACKER_VM"
echo "    Log:   qlab log $ATTACKER_VM"
echo ""
echo "  Credentials (both VMs):"
echo "    Username: labuser"
echo "    Password: labpass"
echo ""
echo "  Wait ~90s for boot + package installation."
echo ""
echo "  Stop both VMs:"
echo "    qlab stop $PLUGIN_NAME"
echo ""
echo "  Stop a single VM:"
echo "    qlab stop $FIREWALL_VM"
echo "    qlab stop $ATTACKER_VM"
echo ""
echo "  Tip: override resources with environment variables:"
echo "    QLAB_MEMORY=4096 QLAB_DISK_SIZE=30G qlab run ${PLUGIN_NAME}"
echo "============================================="
