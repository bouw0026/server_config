#!/bin/bash
# CST8246 Enhanced Lab Configuration Script - Master/Slave DNS Setup
# Version: 7.0 (Enhanced with TSIG, IPv6 validation, and improved dry-run)
# Auto-generated configuration management system

# ============================================================================
# CONFIGURATION VARIABLES - MODIFY THESE FOR YOUR ENVIRONMENT
# ============================================================================

# Student Information
STUDENT_NUMBER="25"
LAB_SECTION="S"
INSTRUCTOR_NAME="Moe"

# Network Configuration
MASTER_IP="172.16.30.25"
SLAVE_IP="172.16.31.25"
ALIAS_IP="172.16.32.25"
MASTER_IP6="2001:db8:30::25"
SLAVE_IP6="2001:db8:31::25"
ALIAS_IP6="2001:db8:32::25"
CLIENT_NET="172.16.31.0/24"
SERVER_NET="172.16.30.0/24"
LOCAL_NET="172.16.0.0/16"

# MAC Addresses (Replace with your actual MACs)
MASTER_MAC="00:50:56:ab:12:cd"
SLAVE_MAC="00:50:56:cd:34:ef"

# Service Ports
DNS_PORT="53"
SSH_PORT="22"

# Domain Configuration
DOMAIN="example25.lab"
MASTER_HOSTNAME="bouw0026-srv"
SLAVE_HOSTNAME="bouw0026-clt"
MASTER_FQDN="${MASTER_HOSTNAME}.${DOMAIN}"
SLAVE_FQDN="${SLAVE_HOSTNAME}.${DOMAIN}"

# SSH Configuration
SSH_USER="cst8246"
SSH_KEY_TYPE="rsa"
SSH_KEY_SIZE="4096"
SSH_KEY_PATH="/home/$SSH_USER/.ssh/id_$SSH_KEY_TYPE"

# System Configuration
HOME="/home/$SSH_USER"
CONFIG_DIR="$HOME/.lab-config"
LOG_FILE="$CONFIG_DIR/lab-config.log"
BACKUP_DIR="$CONFIG_DIR/backups"

# Feature Flags
ENABLE_IPV6=true
ENABLE_SELINUX=true
ENABLE_DNSSEC=true
ENABLE_LOGGING=true
AUTO_BACKUP=true
FIREWALL_TYPE="iptables"

# DNS Configuration
DNS_IPV4_MASTER="172.16.30.25"
DNS_IPV6_MASTER="2001:db8:30::25"
DNS_IPV4_SLAVE="172.16.31.25"
DNS_IPV6_SLAVE="2001:db8:31::25"
DNS_LOCALHOST_IPV4="127.0.0.1"
DNS_LOCALHOST_IPV6="::1"
DNS_RESOLVCONF_FILE="/etc/resolv.conf"
DNS_NSCD_CONFIG="/etc/nscd.conf"
DNS_NSSWITCH_FILE="/etc/nsswitch.conf"

# Runtime Flags
DRY_RUN=false
VALIDATE_ONLY=false
DEBUG_MODE=false

# Lab Test Variations Supported
LAB_VARIATIONS=(
    "master-slave-basic"
    "master-slave-client"
    "ssh-multiuser"
    "firewall-nc-restricted"
    "dns-forward-reverse"
)

# ============================================================================
# COLOR CODES AND LOGGING
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize directories
mkdir -p "$BACKUP_DIR" "$CONFIG_DIR"

# Enhanced logging functions
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$1"; }
log_error() { log "ERROR" "${RED}$1${NC}"; }
log_success() { log "SUCCESS" "${GREEN}$1${NC}"; }
log_warning() { log "WARNING" "${YELLOW}$1${NC}"; }
log_debug() { [ "$DEBUG_MODE" = true ] && log "DEBUG" "${CYAN}$1${NC}"; }

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

backup_file() {
    local file="$1"
    local backup="${BACKUP_DIR}/$(basename "$file").bak.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$file" ]; then
        if [ "$AUTO_BACKUP" = true ]; then
            cp -p "$file" "$backup" && log_info "Backup created: $backup"
        else
            log_debug "Auto-backup disabled, skipping: $file"
        fi
    else
        log_debug "No existing file to backup: $file"
    fi
}


run_command() {
    local cmd="$*"
    local destructive_commands=("chown" "chmod" "rm" "mv" "cp" "mkdir" "systemctl" "iptables" "ip6tables" "useradd" "usermod" "sed" "awk")
    local sensitive_commands=("passwd" "ssh-keygen" "tsig-keygen")
    local dry_run_force_commands=("named-checkconf" "named-checkzone" "dig" "ping" "grep")
    
    # Dry-run mode handling
    if [ "$DRY_RUN" = true ]; then
        # Always allow validation commands to run
        for vcmd in "${dry_run_force_commands[@]}"; do
            if [[ $cmd == *"$vcmd"* ]]; then
                log_debug "[DRY-RUN] Allowing validation command: $cmd"
                eval "$cmd"
                return $?
            fi
        done

        # Check for destructive commands
        for dcmd in "${destructive_commands[@]}"; do
            if [[ $cmd == *"$dcmd"* ]]; then
                log_info "[DRY-RUN] Would execute (destructive): $cmd"
                return 0
            fi
        done

        # Mask sensitive commands
        for scmd in "${sensitive_commands[@]}"; do
            if [[ $cmd == *"$scmd"* ]]; then
                log_info "[DRY-RUN] Would execute (sensitive): [REDACTED]"
                return 0
            fi
        done

        # Allow non-destructive commands to execute
        log_debug "[DRY-RUN] Executing (non-destructive): $cmd"
        eval "$cmd"
        return $?
    fi

    # Validate-only mode handling
    if [ "$VALIDATE_ONLY" = true ]; then
        if [[ $cmd =~ (systemctl|iptables|ip6tables|nmcli|chown|chmod|setsebool|semanage|useradd|usermod) ]]; then
            log_info "[VALIDATE-ONLY] Skipping potentially destructive command: $cmd"
            return 0
        else
            log_debug "[VALIDATE-ONLY] Executing validation command: $cmd"
            eval "$cmd"
            return $?
        fi
    fi

    # Normal execution mode
    log_debug "Executing: $cmd"
    eval "$cmd"
    local exit_code=$?
    
    # Enhanced error handling
    if [ $exit_code -ne 0 ]; then
        log_error "Command failed with exit code $exit_code: $cmd"
        [ "$DEBUG_MODE" = true ] && log_debug "Stack trace: $(caller)"
    fi
    
    return $exit_code
}

with_retry() {
    local max_attempts=3
    local delay=2
    local attempt=1
    local exit_code=0

    while (( attempt <= max_attempts )); do
        if "$@"; then
            return 0
        else
            exit_code=$?
            log_warning "Attempt $attempt failed. Retrying in $delay seconds..."
            sleep $delay
            ((attempt++))
        fi
    done

    log_error "Max attempts reached ($max_attempts) for command: $*"
    return $exit_code
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_full_config() {
    local role="$1"
    local errors=0
    
    # 1. Network validation
    if ! validate_network_config "$role"; then
        ((errors++))
    fi
    
    # 2. DNS validation
    if ! validate_dns_config "$role"; then
        ((errors++))
    fi
    
    # 3. SSH validation
    if ! validate_ssh_config "$role"; then
        ((errors++))
    fi
    
    # 4. Firewall validation
    if ! validate_firewall_config "$role"; then
        ((errors++))
    fi
    
    # 5. Service validation
    if ! validate_services_running "$role"; then
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Full configuration validation passed"
        return 0
    else
        log_error "Configuration validation failed with $errors categories of errors"
        return 1
    fi
}

validate_environment() {
    log_info "Validating environment configuration for student $STUDENT_NUMBER"
    local errors=0
    
    # Validate IP addresses
    for ip in "$MASTER_IP" "$SLAVE_IP" "$ALIAS_IP"; do
        if ! [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            log_error "Invalid IPv4 address: $ip"
            ((errors++))
        fi
    done
    
    # Validate IPv6 if enabled
    if [ "$ENABLE_IPV6" = true ]; then
        for ip6 in "$MASTER_IP6" "$SLAVE_IP6" "$ALIAS_IP6"; do
            if ! [[ $ip6 =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
                log_error "Invalid IPv6 address: $ip6"
                ((errors++))
            fi
        done
    fi
    
    # Check required commands
    for cmd in systemctl iptables dig named-checkzone; do
        if ! command -v $cmd &>/dev/null; then
            log_warning "Command not found: $cmd (may be installed later)"
        fi
    done
    
    if [ $errors -gt 0 ]; then
        log_error "Environment validation failed with $errors errors"
        return 1
    fi
    
    log_success "Environment validation passed"
    return 0
}

# ============================================================================
# NETWORK CONFIGURATION
# ============================================================================

configure_network_interfaces() {
    local role="$1"
    
    log_info "Configuring network interfaces for $role"
    
    # Get MAC addresses
    local mac_ens160=$(ip -o link show dev ens160 2>/dev/null | awk '{print $17}' || echo "")
    local mac_ens224=$(ip -o link show dev ens224 2>/dev/null | awk '{print $17}' || echo "")
    
    case "$role" in
        master)
            configure_master_network "$mac_ens160" "$mac_ens224"
            ;;
        slave)
            configure_slave_network "$mac_ens160" "$mac_ens224"
            ;;
        client)
            configure_client_network "$mac_ens160" "$mac_ens224"
            ;;
    esac
    
    # Restart networking
    run_command "systemctl restart NetworkManager"
    sleep 3
}

configure_master_network() {
    local mac_ens160="$1"
    local mac_ens224="$2"
    
    log_debug "Configuring master network with alias support"
    
    # Master ens160 configuration with alias
    cat > /etc/sysconfig/network-scripts/ifcfg-ens160 <<EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
IPADDR=${MASTER_IP}
IPADDR2=${ALIAS_IP}
PREFIX=16
DEFROUTE=no
IPV4_FAILURE_FATAL=no
$([ "$ENABLE_IPV6" = true ] && echo "IPV6INIT=yes
IPV6ADDR=${MASTER_IP6}/64
IPV6ADDR_SECONDARIES=\"${ALIAS_IP6}/64\"" || echo "IPV6INIT=no")
NAME=ens160
DEVICE=ens160
ONBOOT=yes
PEERDNS=no
${mac_ens160:+HWADDR=$mac_ens160}
EOF

    # Master ens224 configuration (DHCP for internet)
    cat > /etc/sysconfig/network-scripts/ifcfg-ens224 <<EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=dhcp
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
$([ "$ENABLE_IPV6" = true ] && echo "IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes" || echo "IPV6INIT=no")
NAME=ens224
DEVICE=ens224
ONBOOT=yes
PEERDNS=no
${mac_ens224:+HWADDR=$mac_ens224}
EOF

    # Set hostname and hosts entries
    run_command "hostnamectl set-hostname $MASTER_HOSTNAME"
    update_hosts_file "master"
}

configure_slave_network() {
    local mac_ens160="$1"
    local mac_ens224="$2"
    
    log_debug "Configuring slave network"
    
    # Slave ens160 configuration
    cat > /etc/sysconfig/network-scripts/ifcfg-ens160 <<EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
IPADDR=${SLAVE_IP}
PREFIX=16
DEFROUTE=no
IPV4_FAILURE_FATAL=no
$([ "$ENABLE_IPV6" = true ] && echo "IPV6INIT=yes
IPV6ADDR=${SLAVE_IP6}/64" || echo "IPV6INIT=no")
NAME=ens160
DEVICE=ens160
ONBOOT=yes
${mac_ens160:+HWADDR=$mac_ens160}
EOF

    # Slave ens224 configuration
    cat > /etc/sysconfig/network-scripts/ifcfg-ens224 <<EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=dhcp
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
$([ "$ENABLE_IPV6" = true ] && echo "IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_ADDR_GEN_MODE=eui64" || echo "IPV6INIT=no")
NAME=ens224
DEVICE=ens224
ONBOOT=yes
PEERDNS=no
${mac_ens224:+HWADDR=$mac_ens224}
EOF

    # Set hostname and hosts entries
    run_command "hostnamectl set-hostname $SLAVE_HOSTNAME"
    update_hosts_file "slave"
}

update_hosts_file() {
    local role="$1"
    
    backup_file "/etc/hosts"
    
    # Add entries based on role
    case "$role" in
        master|slave)
            echo "$MASTER_IP $MASTER_FQDN $MASTER_HOSTNAME" >> /etc/hosts
            echo "$SLAVE_IP $SLAVE_FQDN $SLAVE_HOSTNAME" >> /etc/hosts
            echo "$ALIAS_IP ftp.$DOMAIN ftp" >> /etc/hosts
            
            if [ "$ENABLE_IPV6" = true ]; then
                echo "$MASTER_IP6 $MASTER_FQDN $MASTER_HOSTNAME" >> /etc/hosts
                echo "$SLAVE_IP6 $SLAVE_FQDN $SLAVE_HOSTNAME" >> /etc/hosts
                echo "$ALIAS_IP6 ftp.$DOMAIN ftp" >> /etc/hosts
            fi
            ;;
        client)
            echo "$MASTER_IP $MASTER_FQDN $MASTER_HOSTNAME ns1.$DOMAIN" >> /etc/hosts
            echo "$SLAVE_IP $SLAVE_FQDN $SLAVE_HOSTNAME ns2.$DOMAIN" >> /etc/hosts
            ;;
    esac
}

# ============================================================================
# MAC-AWARE DNS CONFIGURATION
# ============================================================================

configure_mac_dns() {
    local role="$1"
    
    log_info "Configuring MAC-bound DNS for $role"
    
    # Install required tools if not present
    if ! command -v arp &>/dev/null; then
        run_command "dnf install -y net-tools"
    fi
    
    if ! command -v bpftool &>/dev/null; then
        run_command "dnf install -y bpftool"
    fi

    # Create ARP binding script with validation
    cat > /usr/local/bin/bind_dns_mac <<EOF
#!/bin/bash
# Bind DNS servers to their MAC addresses with validation
validate_mac() {
    local ip=\$1
    local expected_mac=\$2
    current_mac=\$(ip neigh | grep "\$ip" | awk '{print \$5}')
    [ "\$current_mac" = "\$expected_mac" ] && {
        arp -s "\$ip" "\$expected_mac"
        return 0
    }
    logger -t mac_dns "MAC mismatch for \$ip (Expected: \$expected_mac, Found: \$current_mac)"
    return 1
}

validate_mac "$MASTER_IP" "$MASTER_MAC"
validate_mac "$SLAVE_IP" "$SLAVE_MAC"
EOF

    chmod +x /usr/local/bin/bind_dns_mac

    # Enhanced MAC-aware resolver with fallback
    cat > /usr/local/bin/mac_dns_resolver <<EOF
#!/bin/bash
# Verify MAC before DNS resolution with logging
master_mac=\$(ip neigh | grep '$MASTER_IP' | awk '{print \$5}')
if [ "\$master_mac" = "$MASTER_MAC" ]; then
    dig +short "\$@" @$MASTER_IP || dig +short "\$@" @$SLAVE_IP
else
    logger -t mac_dns "MAC verification failed for $MASTER_IP (Expected: $MASTER_MAC, Got: \$master_mac)"
    exit 1
fi
EOF

    chmod +x /usr/local/bin/mac_dns_resolver

    # Configure nsswitch with backup
    backup_file "/etc/nsswitch.conf"
    grep -q '^hosts:.*macdns' /etc/nsswitch.conf || \
        sed -i '/^hosts:/ s/$/ macdns/' /etc/nsswitch.conf

    # Create nss-macdns config with validation
    cat > /etc/nss-macdns.conf <<EOF
# MAC-bound DNS configuration
resolver-program=/usr/local/bin/mac_dns_resolver
fallback-resolver=$ALIAS_IP
mac-whitelist=$MASTER_MAC,$SLAVE_MAC
max-attempts=2
timeout=1
EOF

    # Systemd service with restart logic
    cat > /etc/systemd/system/mac-dns.service <<EOF
[Unit]
Description=MAC-bound DNS configuration
After=network.target
Requires=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bind_dns_mac
ExecReload=/usr/local/bin/bind_dns_mac
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    run_command "systemctl enable --now mac-dns.service"

    # DHCP hook with error handling
    mkdir -p /etc/dhcp/dhclient-enter-hooks.d
    cat > /etc/dhcp/dhclient-enter-hooks.d/mac_dns <<EOF
#!/bin/bash
case \${reason} in
    BOUND|RENEW|REBIND|REBOOT)
        if ! /usr/local/bin/bind_dns_mac; then
            logger -t mac_dns "Failed to bind DNS MAC addresses"
            # Fallback to standard resolution
            sed -i '/macdns/d' /etc/nsswitch.conf
        fi
        ;;
esac
EOF

    chmod +x /etc/dhcp/dhclient-enter-hooks.d/mac_dns

    log_success "MAC-bound DNS configured for $role (Master: $MASTER_MAC, Slave: $SLAVE_MAC)"
}

validate_mac_binding() {
    local ip="$1"
    local expected_mac="$2"
    
    # Ensure ARP cache is populated
    ping -c 1 -W 1 "$ip" >/dev/null 2>&1
    
    # Get current MAC
    local current_mac=$(ip neigh | grep "$ip" | awk '{print $5}')
    
    if [ -z "$current_mac" ]; then
        log_error "Could not determine MAC for $ip - ARP cache empty"
        return 1
    fi
    
    if [ "$current_mac" = "$expected_mac" ]; then
        arp -s "$ip" "$expected_mac"
        return 0
    else
        log_error "MAC mismatch for $ip (Expected: $expected_mac, Found: $current_mac)"
        return 1
    fi
}

# ============================================================================
# DNS MULTI-BIND CONFIGURATION
# ============================================================================

configure_dns_bindings() {
    local role="$1"
    log_info "Configuring multi-protocol DNS bindings for $role"
    
    # Determine which servers to use based on role
    local ipv4_primary="" ipv6_primary=""
    if [ "$role" == "master" ]; then
        ipv4_primary="$DNS_IPV4_MASTER"
        ipv6_primary="$DNS_IPV6_MASTER"
    else
        ipv4_primary="$DNS_IPV4_SLAVE" 
        ipv6_primary="$DNS_IPV6_SLAVE"
    fi

    # Backup existing config
    backup_file "$DNS_RESOLVCONF_FILE"
    
    # Generate new config with all nameservers
    cat > "$DNS_RESOLVCONF_FILE" <<EOF
# Generated by CST8246 DNS Configuration
options timeout:1 attempts:2 rotate
nameserver $DNS_LOCALHOST_IPV4
nameserver $DNS_LOCALHOST_IPV6
nameserver $ipv4_primary
nameserver $ipv6_primary
EOF

    # Configure nsswitch
    backup_file "$DNS_NSSWITCH_FILE"
    sed -i '/^hosts:/ s/files.*/files myhostname dns mdns4_minimal [NOTFOUND=return]/' "$DNS_NSSWITCH_FILE"

    # Enable and configure NSCD if available
    if [ -f "$DNS_NSCD_CONFIG" ]; then
        sed -i 's/^\(enable-cache\s\+hosts\s\+\).*$/\1yes/' "$DNS_NSCD_CONFIG"
        run_command "systemctl restart nscd" 2>/dev/null || true
    fi

    # Configure systemd-resolved if available
    if systemctl is-enabled systemd-resolved &>/dev/null; then
        cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=$DNS_LOCALHOST_IPV4 $DNS_LOCALHOST_IPV6 $ipv4_primary $ipv6_primary
FallbackDNS=8.8.8.8 2001:4860:4860::8888
Domains=~$DOMAIN
EOF
        run_command "systemctl restart systemd-resolved"
    fi

    # Lock configuration
    chattr +i "$DNS_RESOLVCONF_FILE" 2>/dev/null || true
    
    log_success "DNS multi-bind configured for $role"
}

# ============================================================================
# ARP SECURITY CONFIGURATION
# ============================================================================

configure_arp_security() {
    log_info "Configuring ARP security hardening"
    
    # Enable ARP filtering
    echo 1 > /proc/sys/net/ipv4/conf/all/arp_filter
    echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore
    echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce
    
    # Make settings persistent
    cat > /etc/sysctl.d/10-arp-security.conf <<EOF
net.ipv4.conf.all.arp_filter = 1
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.all.secure_redirects = 0
EOF
    run_command "sysctl -p /etc/sysctl.d/10-arp-security.conf"
    
    log_success "ARP security configured"
}

# ============================================================================
# NETWORK CONFIGURATION MAIN FUNCTION
# ============================================================================

configure_network() {
    local role="$1"
    log_info "Configuring network for $role (Student: $STUDENT_NUMBER)"
    
    # 1. Base network configuration
    configure_network_interfaces "$role"
    
    # 2. MAC-aware DNS binding
    configure_mac_dns "$role"
    
    # 3. Multi-protocol DNS binding
    configure_dns_bindings "$role"
    
    # 4. ARP security hardening
    configure_arp_security
    
    # 5. Firewall configuration
    configure_firewall "$role"
    
    # 6. Final verification
    verify_network_config "$role"
    
    log_success "Network configuration completed for $role"
}

verify_network_config() {
    local role="$1"
    
    log_info "Verifying network configuration for $role"
    
    # Check interface status
    ip -br addr show | grep -E 'ens160|ens224' | while read line; do
        log_debug "Interface status: $line"
    done
    
    # Test connectivity
    if ping -c 1 -W 2 "$MASTER_IP" &>/dev/null; then
        log_success "Master IP ($MASTER_IP) is reachable"
    else
        log_warning "Master IP ($MASTER_IP) is not reachable"
    fi
    
    if [ "$role" != "master" ] && ping -c 1 -W 2 "$SLAVE_IP" &>/dev/null; then
        log_success "Slave IP ($SLAVE_IP) is reachable"
    fi
}

# ============================================================================
# FIREWALL CONFIGURATION
# ============================================================================

configure_firewall() {
    local role="$1"
    log_info "Configuring $FIREWALL_TYPE firewall for $role"
    
    if [ "$FIREWALL_TYPE" = "iptables" ]; then
        configure_iptables_firewall "$role"
    elif [ "$FIREWALL_TYPE" = "firewalld" ]; then
        configure_firewalld_firewall "$role"
    else
        log_error "Unknown firewall type: $FIREWALL_TYPE"
        return 1
    fi
    
    log_success "Firewall configured for $role"
}

configure_iptables_firewall() {
    local role="$1"
    
    # Stop and disable firewalld
    run_command "systemctl stop firewalld 2>/dev/null"
    run_command "systemctl disable firewalld 2>/dev/null"
    
    # Install and enable iptables
    run_command "dnf install -y iptables-services"
    run_command "systemctl enable --now iptables"
    
    # Clear existing rules
    run_command "iptables -F"
    run_command "iptables -P INPUT ACCEPT"
    run_command "iptables -P FORWARD ACCEPT"
    run_command "iptables -P OUTPUT ACCEPT"
    
    # Common rules
    run_command "iptables -A INPUT -i lo -j ACCEPT"
    run_command "iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT"
    run_command "iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT"
    run_command "iptables -A INPUT -p tcp --dport $DNS_PORT -j ACCEPT"
    run_command "iptables -A INPUT -p udp --dport $DNS_PORT -j ACCEPT"
    
    # IPv6 rules if enabled
    if [ "$ENABLE_IPV6" = true ]; then
        run_command "ip6tables -A INPUT -i lo -j ACCEPT"
        run_command "ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT"
        run_command "ip6tables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT"
        run_command "ip6tables -A INPUT -p tcp --dport $DNS_PORT -j ACCEPT"
        run_command "ip6tables -A INPUT -p udp --dport $DNS_PORT -j ACCEPT"
    fi
    
    # Role-specific rules based on lab requirements
    case "$role" in
        master)
            # Allow SSH from client network, reject from server network
            run_command "iptables -A INPUT -s $CLIENT_NET -p tcp --dport $SSH_PORT -j ACCEPT"
            run_command "iptables -A INPUT -s $SERVER_NET -p tcp --dport $SSH_PORT -j REJECT"
            
            # NC port 49876 - allow from client, reject from server (Lab Test requirement)
            run_command "iptables -A INPUT -s $CLIENT_NET -p tcp --dport 49876 -j ACCEPT"
            run_command "iptables -A INPUT -p tcp --dport 49876 -j REJECT"
            ;;
        slave)
            # Allow SSH from server network, reject from client network
            run_command "iptables -A INPUT -s $SERVER_NET -p tcp --dport $SSH_PORT -j ACCEPT"
            run_command "iptables -A INPUT -s $CLIENT_NET -p tcp --dport $SSH_PORT -j REJECT"
            
            # NC port 55765 - allow from alias and server, reject from client (Lab Test requirement)
            run_command "iptables -A INPUT -s $SERVER_NET -p tcp --dport 55765 -j ACCEPT"
            run_command "iptables -A INPUT -s ${ALIAS_IP}/32 -p tcp --dport 55765 -j ACCEPT"
            run_command "iptables -A INPUT -s $CLIENT_NET -p tcp --dport 55765 -j REJECT"
            ;;
        client)
            # Basic client firewall
            run_command "iptables -A INPUT -s $LOCAL_NET -j ACCEPT"
            ;;
    esac
    
    # Save rules
    run_command "iptables-save > /etc/sysconfig/iptables"
    if [ "$ENABLE_IPV6" = true ]; then
        run_command "ip6tables-save > /etc/sysconfig/ip6tables"
    fi
}

# ============================================================================
# SSH CONFIGURATION
# ============================================================================

install_ssh() {
    local role="$1"
    log_info "Installing OpenSSH packages for $role"
    
    case "$role" in
        master)
            run_command "dnf install -y openssh-server openssh-clients"
            run_command "systemctl enable --now sshd"
            log_success "OpenSSH server and client installed"
            ;;
        slave|client)
            run_command "dnf install -y openssh-clients openssh-server"
            run_command "systemctl enable --now sshd"
            log_success "OpenSSH client and server installed"
            ;;
    esac

    configure_ssh_initial "$role"
}

configure_ssh_initial() {
    local role="$1"
    log_info "Applying initial SSH configuration for $role"
    
    backup_file "/etc/ssh/sshd_config"
    
    # Generate SSH configuration based on role and lab requirements
    generate_ssh_config "$role" "initial"
    
    run_command "systemctl restart sshd"
    log_success "Initial SSH configuration applied for $role"
}

generate_ssh_config() {
    local role="$1"
    local phase="$2"  # initial or final
    
    local listen_addresses=""
    local permit_root="yes"
    local password_auth="yes"
    local pubkey_auth="yes"
    
    # Set listen addresses based on role
    case "$role" in
        master)
            listen_addresses="ListenAddress $MASTER_IP\nListenAddress $ALIAS_IP"
            ;;
        slave)
            listen_addresses="ListenAddress $SLAVE_IP"
            ;;
        client)
            listen_addresses="ListenAddress 172.16.31.$STUDENT_NUMBER"
            ;;
    esac
    
    # Adjust security based on phase
    if [ "$phase" = "final" ]; then
        permit_root="no"
        password_auth="no"
    fi
    
    cat > /etc/ssh/sshd_config <<EOF
Port $SSH_PORT
$listen_addresses
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTHPRIV
PermitRootLogin $permit_root
PubkeyAuthentication $pubkey_auth
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication $password_auth
ChallengeResponseAuthentication no
GSSAPIAuthentication yes
GSSAPICleanupCredentials no
UsePAM yes
X11Forwarding yes
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS
Subsystem sftp /usr/libexec/openssh/sftp-server
AllowUsers $SSH_USER root lab foo
EOF
}

configure_ssh_keys() {
    log_info "Configuring SSH keys for user $SSH_USER"
    
    # Create SSH directory
    run_command "mkdir -p $(dirname $SSH_KEY_PATH)"
    
    # Generate SSH key if it doesn't exist
    if [ ! -f "$SSH_KEY_PATH" ]; then
        run_command "ssh-keygen -t $SSH_KEY_TYPE -b $SSH_KEY_SIZE -f $SSH_KEY_PATH -N \"\""
    fi
    
    # Set proper ownership and permissions
    run_command "chown -R $SSH_USER:$SSH_USER $(dirname $SSH_KEY_PATH)"
    run_command "chmod 700 $(dirname $SSH_KEY_PATH)"
    run_command "chmod 600 $SSH_KEY_PATH*"
    
    log_success "SSH keys configured with correct permissions"
}

# ============================================================================
# DNS CONFIGURATION
# ============================================================================

configure_master_dns() {
    log_info "Configuring Master DNS server for domain $DOMAIN"
    
    if [ "$ENABLE_LOGGING" = true ]; then
        setup_dns_logging
    fi
    
    run_command "dnf install -y bind bind-utils"
    backup_file "/etc/named.conf"
    
    # Generate master named.conf with IPv6 fixes
    generate_master_named_conf
    
    # Generate zone files
    generate_forward_zone
    generate_reverse_zone
    
    if [ "$ENABLE_IPV6" = true ]; then
        generate_ipv6_reverse_zone
    fi
    
    # Configure zone transfers and TSIG keys
    configure_zone_transfers
    [ "$ENABLE_DNSSEC" = true ] && configure_tsig_keys
    
    # Set permissions and ownership
    run_command "chown root:named /var/named/*.zone /var/named/rev.*"
    run_command "chmod 640 /var/named/*.zone /var/named/rev.*"
    
    if [ "$ENABLE_SELINUX" = true ]; then
        run_command "restorecon -Rv /var/named"
        run_command "setsebool -P named_write_master_zones 1"
    fi
    
    # Validate configuration
    validate_dns_config "master"
    
    # Start service
    run_command "systemctl enable --now named"
    with_retry systemctl restart named
    
    log_success "Master DNS configuration completed"
}

configure_zone_transfers() {
    log_info "Configuring secure zone transfers"
    
    # Verify SELinux contexts
    run_command "restorecon -Rv /var/named"
    run_command "chcon -t named_zone_t /var/named/*"
    
    # Verify permissions
    run_command "chown named:named /var/named/*"
    run_command "chmod 640 /var/named/*"
    
    # Check allow-transfer includes IPv6
    if [ "$ENABLE_IPV6" = true ]; then
        if ! grep -q "allow-transfer.*$SLAVE_IP6" /etc/named.conf; then
            log_error "Missing IPv6 slave in allow-transfer"
            return 1
        fi
    fi
    
    log_success "Zone transfer configuration completed"
}

validate_ipv6_reverse_zone() {
    [ "$ENABLE_IPV6" = false ] && return 0
    
    local zone_file="/var/named/$DOMAIN.ip6.arpa"
    local errors=0
    
    # Check $ORIGIN exists and is correct
    if ! grep -q '^\$ORIGIN' "$zone_file"; then
        log_error "Missing \$ORIGIN in IPv6 reverse zone file"
        ((errors++))
    fi
    
    # Validate nibble format for PTR records
    local master_ptr="5.2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.3.0.0"
    if ! grep -q "^$master_ptr" "$zone_file"; then
        log_error "IPv6 PTR record format incorrect - check nibble reversal"
        ((errors++))
    fi
    
    # Check empty zones are disabled in named.conf
    if ! grep -q "disable-empty-zone.*ip6.arpa" /etc/named.conf; then
        log_error "IPv6 empty zones not properly disabled"
        ((errors++))
    fi
    
    return $errors
}

configure_tsig_keys() {
    log_info "Configuring TSIG keys for secure zone transfers"
    
    local key_name="lab-tsig-key"
    local key_file="/etc/named/tsig.key"
    
    # Generate key if doesn't exist
    if [ ! -f "$key_file" ]; then
        run_command "tsig-keygen -a hmac-sha256 $key_name > $key_file"
        run_command "chown named:named $key_file"
        run_command "chmod 640 $key_file"
    fi
    
    # Add to named.conf on master
    run_command "sed -i '/options {/a include \"$key_file\";' /etc/named.conf"
    
    # Configure zone transfers to use TSIG
    run_command "sed -i '/allow-transfer/a server $SLAVE_IP { keys \"$key_name\"; };' /etc/named.conf"
    
    if [ "$ENABLE_IPV6" = true ]; then
        run_command "sed -i '/allow-transfer/a server $SLAVE_IP6 { keys \"$key_name\"; };' /etc/named.conf"
    fi
    
    log_success "TSIG key configuration completed"
}

validate_dns_config() {
    local role="$1"
    local errors=0
    
    log_info "Validating DNS configuration for $role"
    
    # Check named.conf syntax
    if command -v named-checkconf &>/dev/null; then
        if named-checkconf -z /etc/named.conf; then
            log_success "named.conf syntax is valid"
        else
            log_error "named.conf has syntax errors"
            ((errors++))
        fi
    fi
    
    # Check zone files for master
    if [ "$role" = "master" ]; then
        if command -v named-checkzone &>/dev/null; then
            if ! named-checkzone "$DOMAIN" "/var/named/$DOMAIN.zone"; then
                log_error "Forward zone validation failed"
                ((errors++))
            fi
            
            if ! named-checkzone "16.172.in-addr.arpa" "/var/named/rev.16.172"; then
                log_error "IPv4 reverse zone validation failed"
                ((errors++))
            fi
            
            if [ "$ENABLE_IPV6" = true ] && ! validate_ipv6_reverse_zone; then
                log_error "IPv6 reverse zone validation failed"
                ((errors++))
            fi
        fi
    fi
    
    return $errors
}

generate_master_named_conf() {
    cat > /etc/named.conf <<EOF
//
// BIND Configuration File - Master DNS Server
// Enhanced with IPv6 fixes and empty zone handling
//

options {
    // Basic directories and files
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";

    // Network listening - explicit IPv6 support
    listen-on port 53 { 127.0.0.1; $MASTER_IP; };
    listen-on-v6 port 53 { ::1; $MASTER_IP6; };
    
    // Access control
    allow-query { 
        localhost; 
        $LOCAL_NET;
        2001:db8::/32;
    };
    
    allow-recursion { 
        localhost; 
        $LOCAL_NET;
        2001:db8::/32;
    };
    
    allow-transfer { 
        $SLAVE_IP;
        $SLAVE_IP6;
    };

    // Critical fix for IPv6 reverse DNS - disable empty zones
    disable-empty-zone "0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa";
    disable-empty-zone "8.B.D.0.1.0.0.2.IP6.ARPA";

    // DNS features
    recursion yes;
    dnssec-enable yes;
    dnssec-validation yes;

    // Zone settings
    $([ "$ENABLE_LOGGING" = true ] && echo "zone-statistics yes;")
    notify explicit;
    also-notify { 
        $SLAVE_IP;
        $SLAVE_IP6;
    };

    // Performance tuning
    max-cache-size 90%;
    
    // Security enhancements
    rate-limit {
        responses-per-second 10;
        window 5;
    };
};

// Forward Zone
zone "$DOMAIN" IN {
    type master;
    file "/var/named/$DOMAIN.zone";
    allow-transfer { 
        $SLAVE_IP; 
        $SLAVE_IP6;
    };
    $([ "$ENABLE_LOGGING" = true ] && echo "zone-statistics yes;")
};

// IPv4 Reverse Zone
zone "16.172.in-addr.arpa" IN {
    type master;
    file "/var/named/rev.16.172";
    allow-transfer { 
        $SLAVE_IP;
        $SLAVE_IP6;
    };
    $([ "$ENABLE_LOGGING" = true ] && echo "zone-statistics yes;")
};

$([ "$ENABLE_IPV6" = true ] && cat <<IPV6_ZONE
// IPv6 Reverse Zone - Critical Fix
zone "0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa" IN {
    type master;
    file "/var/named/$DOMAIN.ip6.arpa";
    allow-transfer { 
        $SLAVE_IP6;
    };
    $([ "$ENABLE_LOGGING" = true ] && echo "zone-statistics yes;")
};
IPV6_ZONE
)

// Standard includes
include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF
}

generate_forward_zone() {
    local serial=$(date +%Y%m%d)01
    
    cat > /var/named/$DOMAIN.zone <<EOF
\$TTL 86400
\$ORIGIN $DOMAIN.

@   IN  SOA     ns1.$DOMAIN. dnsadmin.$DOMAIN. (
    $serial           ; Serial
    3600              ; Refresh
    1800              ; Retry
    604800            ; Expire
    86400             ; Minimum TTL
)

; Name servers
@       IN  NS   ns1.$DOMAIN.
@       IN  NS   ns2.$DOMAIN.

; A records
ns1     IN  A    $MASTER_IP
ns2     IN  A    $SLAVE_IP
ftp     IN  A    $ALIAS_IP

$([ "$ENABLE_IPV6" = true ] && cat <<IPV6_RECORDS
; AAAA records
ns1     IN  AAAA $MASTER_IP6
ns2     IN  AAAA $SLAVE_IP6
ftp     IN  AAAA $ALIAS_IP6
IPV6_RECORDS
)

; Additional records for lab testing
www     IN  CNAME ftp
mail    IN  A    $MASTER_IP
EOF
}

generate_reverse_zone() {
    local serial=$(date +%Y%m%d)01
    
    cat > /var/named/rev.16.172 <<EOF
\$TTL 86400
\$ORIGIN 16.172.in-addr.arpa.

@       IN  SOA     ns1.$DOMAIN. dnsadmin.$DOMAIN. (
    $serial           ; Serial
    3600              ; Refresh
    1800              ; Retry
    604800            ; Expire
    86400             ; Minimum TTL
)

; Name servers
@       IN  NS   ns1.$DOMAIN.
@       IN  NS   ns2.$DOMAIN.

; PTR records
25.30   IN  PTR  ns1.$DOMAIN.
25.31   IN  PTR  ns2.$DOMAIN.
25.32   IN  PTR  ftp.$DOMAIN.
EOF
}

generate_ipv6_reverse_zone() {
    local serial=$(date +%Y%m%d)01
    
    cat > /var/named/$DOMAIN.ip6.arpa <<EOF
\$TTL 86400
\$ORIGIN 0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa.

@ IN SOA ns1.$DOMAIN. admin.$DOMAIN. (
    $serial           ; serial
    3600              ; refresh
    1800              ; retry
    604800            ; expire
    86400             ; minimum
)

@ IN NS ns1.$DOMAIN.
@ IN NS ns2.$DOMAIN.

; PTR record for 2001:db8:30::25 (fully expanded)
5.2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.3.0.0 IN PTR ns1.$DOMAIN.
; PTR record for 2001:db8:31::25 (fully expanded)
5.2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.3.0 IN PTR ns2.$DOMAIN.
EOF
}

configure_slave_dns() {
    log_info "Configuring Slave DNS server for domain $DOMAIN"
    
    run_command "dnf install -y bind bind-utils"
    backup_file "/etc/named.conf"
    
    # Generate slave named.conf
    generate_slave_named_conf
    
    # Create slave directories
    run_command "mkdir -p /var/named/slaves"
    run_command "chown named:named /var/named/slaves"
    run_command "chmod 770 /var/named/slaves"
    
    if [ "$ENABLE_SELINUX" = true ]; then
        run_command "restorecon -Rv /var/named/slaves"
        run_command "setsebool -P named_write_master_zones 1"
    fi
    
    # Configure resolv.conf
    backup_file "/etc/resolv.conf"
    generate_resolv_conf
    
    # Start service
    run_command "systemctl enable --now named"
    with_retry systemctl restart named
    
    # Validate configuration
    validate_dns_config "slave"
    
    log_success "Slave DNS configuration completed"
}

generate_slave_named_conf() {
    cat > /etc/named.conf <<EOF
options {
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    
    // Network listening
    listen-on port 53 { 127.0.0.1; $SLAVE_IP; };
    listen-on-v6 port 53 { ::1; $SLAVE_IP6; };
    
    $([ "$ENABLE_LOGGING" = true ] && echo "zone-statistics yes;")
    
    allow-query { localhost; $LOCAL_NET; 2001:db8::/32; };
    allow-transfer { none; };
    allow-recursion { localhost; $LOCAL_NET; 2001:db8::/32; };
    
    $([ "$ENABLE_DNSSEC" = true ] && echo "dnssec-enable yes;
    dnssec-validation yes;")
};

zone "$DOMAIN" IN {
    type slave;
    file "slaves/$DOMAIN.zone";
    masters { $MASTER_IP; $([ "$ENABLE_IPV6" = true ] && echo "$MASTER_IP6;") };
    $([ "$ENABLE_LOGGING" = true ] && echo "zone-statistics yes;")
};

zone "16.172.in-addr.arpa" IN {
    type slave;
    file "slaves/rev.16.172";
    masters { $MASTER_IP; $([ "$ENABLE_IPV6" = true ] && echo "$MASTER_IP6;") };
    $([ "$ENABLE_LOGGING" = true ] && echo "zone-statistics yes;")
};

$([ "$ENABLE_IPV6" = true ] && cat <<IPV6_SLAVE_ZONE
zone "0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa" IN {
    type slave;
    file "slaves/$DOMAIN.ip6.arpa";
    masters { $MASTER_IP6; };
    $([ "$ENABLE_LOGGING" = true ] && echo "zone-statistics yes;")
};
IPV6_SLAVE_ZONE
)

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF
}

generate_resolv_conf() {
    cat > /etc/resolv.conf <<EOF
search $DOMAIN
nameserver $MASTER_IP
$([ "$ENABLE_IPV6" = true ] && echo "nameserver $MASTER_IP6")
EOF
}

validate_dns_config() {
    local role="$1"
    
    log_info "Validating DNS configuration for $role"
    
    # Check named.conf syntax
    if command -v named-checkconf &>/dev/null; then
        if named-checkconf -z /etc/named.conf; then
            log_success "named.conf syntax is valid"
        else
            log_error "named.conf has syntax errors"
            return 1
        fi
    fi
    
    # Check zone files for master
    if [ "$role" = "master" ]; then
        if command -v named-checkzone &>/dev/null; then
            if named-checkzone "$DOMAIN" "/var/named/$DOMAIN.zone" && \
               named-checkzone "16.172.in-addr.arpa" "/var/named/rev.16.172"; then
                log_success "Zone files are valid"
            else
                log_error "Zone file validation failed"
                return 1
            fi
        fi
    fi
    
    return 0
}

# ============================================================================
# LAB TEST SPECIFIC FUNCTIONS
# ============================================================================

setup_nc_service() {
    local role="$1"
    local port="$2"
    
    log_info "Setting up NC service on port $port for $role"
    
    # Install netcat if not present
    run_command "dnf install -y nmap-ncat"
    
    # Create systemd service for NC
    cat > /etc/systemd/system/nc-lab.service <<EOF
[Unit]
Description=Netcat Lab Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/nc -l $port
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
EOF
    
    run_command "systemctl daemon-reload"
    run_command "systemctl enable --now nc-lab"
    
    log_success "NC service configured on port $port"
}

setup_lab_users() {
    log_info "Setting up lab users for testing"
    
    # Create lab user (Lab Test requirement)
    if ! id "lab" &>/dev/null; then
        run_command "useradd -m -s /bin/bash lab"
        echo "test" | passwd --stdin lab
        log_success "Created lab user with password 'test'"
    fi
    
    # Create foo user for SSH testing
    if ! id "foo" &>/dev/null; then
        run_command "useradd -m -s /bin/bash foo"
        run_command "mkdir -p /home/foo/.ssh"
        run_command "chown foo:foo /home/foo/.ssh"
        run_command "chmod 700 /home/foo/.ssh"
        log_success "Created foo user for SSH key testing"
    fi
    
    # Ensure cst8246 user exists
    if ! id "$SSH_USER" &>/dev/null; then
        run_command "useradd -m -s /bin/bash $SSH_USER"
        log_success "Created $SSH_USER user"
    fi
}

# ============================================================================
# VERIFICATION FUNCTIONS
# ============================================================================

verify_dns_bindings() {
    local role="$1"
    local errors=0
    
    log_info "Verifying DNS bindings for $role"
    
    # Expected servers based on role
    local expected_servers=("$DNS_LOCALHOST_IPV4" "$DNS_LOCALHOST_IPV6")
    if [ "$role" == "master" ]; then
        expected_servers+=("$DNS_IPV4_MASTER" "$DNS_IPV6_MASTER")
    else
        expected_servers+=("$DNS_IPV4_SLAVE" "$DNS_IPV6_SLAVE") 
    fi

    # Check resolv.conf contains all expected servers
    for server in "${expected_servers[@]}"; do
        if ! grep -q "^nameserver $server" "$DNS_RESOLVCONF_FILE"; then
            log_error "Missing nameserver: $server"
            ((errors++))
        fi
    done

    # Test resolution for each protocol
    if ! dig +short +time=1 example.com @$DNS_LOCALHOST_IPV4 >/dev/null; then
        log_error "IPv4 localhost resolution failed"
        ((errors++))
    fi
    
    if ! dig +short +time=1 example.com @$DNS_LOCALHOST_IPV6 >/dev/null; then
        log_warning "IPv6 localhost resolution failed (may be expected if IPv6 disabled)"
        [ "$ENABLE_IPV6" = true ] && ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "DNS bindings verification passed"
    else
        log_error "DNS bindings verification failed with $errors errors"
    fi
    
    return $errors
}

verify_ipv6_dns() {
    local errors=0
    
    log_info "Comprehensive IPv6 DNS verification"
    
    # 1. Check IPv6 connectivity
    if ! ping6 -c1 -W2 $DNS_IPV6_MASTER >/dev/null; then
        log_error "IPv6 connectivity to DNS server failed"
        ((errors++))
    fi

    # 2. Check DNS server listening
    if ! netstat -tuln | grep -q "\[::\]:53"; then
        log_error "DNS server not listening on IPv6"
        ((errors++))
    fi

    # 3. Test forward resolution
    if ! dig +short +time=2 +tries=1 AAAA $MASTER_FQDN @$DNS_IPV6_MASTER >/dev/null; then
        log_error "IPv6 forward resolution failed"
        ((errors++))
    fi

    # 4. Test reverse resolution
    if ! dig +short +time=2 +tries=1 -x $DNS_IPV6_MASTER @$DNS_IPV6_MASTER >/dev/null; then
        log_error "IPv6 reverse resolution failed"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        log_success "IPv6 DNS fully operational"
        return 0
    else
        log_error "IPv6 DNS has $errors configuration issues"
        return 1
    fi
}

verify_arp_security() {
    local errors=0
    
    # Check static ARP entries
    if ! arp -n | grep -q "$MASTER_IP.*[Pp]ermanent"; then
        log_error "Missing static ARP entry for master"
        ((errors++))
    fi
    
    # Check kernel settings
    if [ $(cat /proc/sys/net/ipv4/conf/all/arp_filter) -ne 1 ]; then
        log_error "ARP filtering not enabled"
        ((errors++))
    fi
    
    return $errors
}

verify_all_services() {
    local verbose="${1:-false}"
    local role="${2:-unknown}"
    
    echo -e "\n${PURPLE}=== Comprehensive Service Verification ===${NC}"
    echo -e "Student: $STUDENT_NUMBER | Role: $role | Domain: $DOMAIN"
    echo -e "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    
    verify_network_config "$role"
    verify_dns_bindings "$role"
    verify_ipv6_dns
    verify_arp_security
    
    echo -e "\n${GREEN}=== Verification Summary ===${NC}"
    log_success "Comprehensive verification completed"
}

# ============================================================================
# MAIN SETUP FUNCTIONS
# ============================================================================

setup_master_server() {
    log_info "Setting up Master DNS server (Student: $STUDENT_NUMBER)"
    
    setup_lab_users
    install_ssh master
    configure_network "master"
    configure_master_dns
    
    # Lab test specific services
    setup_nc_service master 49876
    
    log_success "Master server setup completed"
}

setup_slave_server() {
    log_info "Setting up Slave DNS server (Student: $STUDENT_NUMBER)"
    
    setup_lab_users
    install_ssh slave
    configure_network slave
    configure_slave_dns
    
    # Lab test specific services
    setup_nc_service slave 55765
    
    log_success "Slave server setup completed"
}

setup_client_system() {
    log_info "Setting up Client system (Student: $STUDENT_NUMBER)"
    
    setup_lab_users
    install_ssh client
    configure_network client
    
    # Configure client to use DNS servers
    backup_file "/etc/resolv.conf"
    cat > /etc/resolv.conf <<EOF
search $DOMAIN
nameserver $MASTER_IP
nameserver $SLAVE_IP
EOF
    
    log_success "Client system setup completed"
}

# ============================================================================
# SSH KEY EXCHANGE FUNCTIONS
# ============================================================================

exchange_ssh_keys() {
    local direction="$1"
    
    log_info "Exchanging SSH keys: $direction"
    
    case "$direction" in
        master-to-slave)
            wait_for_ssh "$SLAVE_IP"
            echo "Enter password for $SSH_USER@$SLAVE_IP when prompted:"
            sudo -u "$SSH_USER" ssh-copy-id -f -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH.pub" "$SSH_USER@$SLAVE_IP"
            
            if sudo -u "$SSH_USER" ssh -o BatchMode=yes "$SSH_USER@$SLAVE_IP" exit; then
                log_success "SSH key exchange successful: master to slave"
            else
                log_error "SSH key exchange failed: master to slave"
                return 1
            fi
            ;;
        slave-to-master)
            wait_for_ssh "$MASTER_IP"
            echo "Enter password for $SSH_USER@$MASTER_IP when prompted:"
            sudo -u "$SSH_USER" ssh-copy-id -f -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH.pub" "$SSH_USER@$MASTER_IP"
            
            if sudo -u "$SSH_USER" ssh -o BatchMode=yes "$SSH_USER@$MASTER_IP" exit; then
                log_success "SSH key exchange successful: slave to master"
            else
                log_error "SSH key exchange failed: slave to master"
                return 1
            fi
            ;;
    esac
}

wait_for_ssh() {
    local host=$1
    local max_attempts=30
    local attempt=0
    
    log_info "Waiting for SSH service on $host"
    while ! nc -z -w 1 "$host" $SSH_PORT 2>/dev/null; do
        sleep 1
        attempt=$((attempt+1))
        if [ $attempt -ge $max_attempts ]; then
            log_error "SSH service on $host did not become available"
            return 1
        fi
    done
    log_info "SSH service on $host is available"
}

finalize_ssh_config() {
    local role="$1"
    log_info "Finalizing SSH configuration for $role"
    
    # Apply final SSH configuration (key-only access)
    generate_ssh_config "$role" "final"
    run_command "systemctl restart sshd"
    
    log_success "SSH configuration finalized for $role"
}

# ============================================================================
# USAGE AND HELP
# ============================================================================

show_usage() {
    cat <<EOF
${BLUE}=== Enhanced DNS Master/Slave Configuration Tool v6.4 ===${NC}

${GREEN}Main Commands:${NC}
  master              Complete master DNS server setup
  slave               Complete slave DNS server setup
  client              Complete client system setup
  
${GREEN}SSH Key Management:${NC}
  exchange-keys       Interactive SSH key exchange setup
  master-to-slave     Exchange keys from master to slave
  slave-to-master     Exchange keys from slave to master
  finalize-ssh        Apply final SSH security configuration

${GREEN}Verification Commands:${NC}
  verify [role]       Comprehensive verification of all services
  verify-dns          DNS-specific verification
  verify-ssh          SSH-specific verification
  verify-firewall     Firewall-specific verification

${GREEN}Lab Test Commands:${NC}
  lab-test-setup      Setup for specific lab test requirements
  nc-setup [port]     Setup netcat service for testing

${GREEN}Options:${NC}
  --dry-run           Simulate changes without executing
  --debug             Enable debug output
  --validate          Validate configuration only
  --help              Show this help message

${YELLOW}Current Configuration:${NC}
  Student Number:     ${STUDENT_NUMBER}
  Lab Section:        ${LAB_SECTION}
  Master IP:          ${MASTER_IP}
  Slave IP:           ${SLAVE_IP}
  Alias IP:           ${ALIAS_IP}
  Domain:             ${DOMAIN}
  IPv6 Support:       ${ENABLE_IPV6}
  SELinux:            ${ENABLE_SELINUX}
  Firewall Type:      ${FIREWALL_TYPE}

${YELLOW}Lab Test Variations Supported:${NC}
$(printf "  %s\n" "${LAB_VARIATIONS[@]}")

${RED}Note:${NC} This script must be run as root
${RED}Note:${NC} Modify configuration variables at the top of this script

${BLUE}Examples:${NC}
  $0 master                    # Setup master server
  $0 slave                     # Setup slave server  
  $0 master-to-slave           # Exchange SSH keys
  $0 verify master             # Verify master configuration
  $0 --debug verify slave      # Debug slave verification
  $0 --dry-run master          # Simulate master setup

EOF
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    local command="$1"
    shift
    
    # Parse command line options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                log_info "Dry-run mode enabled"
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                log_info "Debug mode enabled"
                shift
                ;;
            --validate)
                VALIDATE_ONLY=true
                log_info "Validation-only mode enabled"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi
    
    # Execute command
    case "$command" in
        master)
            setup_master_server
            verify_all_services false master
            ;;
        slave)
            setup_slave_server
            verify_all_services false slave
            ;;
        client)
            setup_client_system
            verify_all_services false client
            ;;
        master-to-slave|masterpub)
            exchange_ssh_keys "master-to-slave"
            finalize_ssh_config master
            ;;
        slave-to-master|slavepub)
            exchange_ssh_keys "slave-to-master"
            finalize_ssh_config slave
            ;;
        exchange-keys)
            echo "Choose key exchange direction:"
            echo "1) Master to Slave"
            echo "2) Slave to Master"
            echo "3) Both directions"
            read -p "Enter choice (1-3): " choice
            case "$choice" in
                1) exchange_ssh_keys "master-to-slave" ;;
                2) exchange_ssh_keys "slave-to-master" ;;
                3) 
                    exchange_ssh_keys "master-to-slave"
                    exchange_ssh_keys "slave-to-master"
                    ;;
                *) log_error "Invalid choice" ;;
            esac
            ;;
        verify)
            local role="${1:-unknown}"
            verify_all_services true "$role"
            ;;
        verify-dns|mdns|sdns)
            verify_dns_bindings "${1:-unknown}"
            verify_ipv6_dns
            ;;
        verify-ssh)
            verify_ssh_access "${1:-unknown}"
            ;;
        verify-firewall)
            verify_firewall "${1:-unknown}"
            ;;
        nc-setup)
            local port="${1:-49876}"
            setup_nc_service "${2:-master}" "$port"
            ;;
        lab-test-setup)
            log_info "Setting up for lab test requirements"
            setup_lab_users
            log_success "Lab test setup completed"
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
    
    log_success "Operation completed successfully!"
    log_info "Log file: $LOG_FILE"
    log_info "Backup directory: $BACKUP_DIR"
}

# Call main function with all arguments
main "$@"