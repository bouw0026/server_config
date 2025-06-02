#!/bin/bash

source "$(dirname "$0")/config.sh"

configure_network() {
    local interface="${1:-$DEFAULT_INTERFACE}"
    log_info "Configuring interface $interface"

    # Get current IP
    local current_ip=$(ip -o -4 addr show "$interface" | awk '{print $4}' | cut -d'/' -f1 | head -1)
    
    # Generate interface config
    local config_file="/etc/sysconfig/network-scripts/ifcfg-${interface}"
    backup_file "$config_file"
    
    cat > "$config_file" << EOF
DEVICE=$interface
BOOTPROTO=static
IPADDR=$current_ip
NETMASK=255.255.255.0
ONBOOT=yes
EOF

    log_info "Interface $interface configured with IP $current_ip"
}

set_hostname() {
    local hostname="${1:-$DEFAULT_HOSTNAME}"
    log_info "Setting hostname to $hostname"
    hostnamectl set-hostname "$hostname"
}

update_hosts() {
    log_info "Updating /etc/hosts"
    backup_file "/etc/hosts"
    
    cat > "/etc/hosts" << EOF
127.0.0.1   localhost localhost.localdomain
$DEFAULT_SERVER_IP   $DEFAULT_HOSTNAME.$DEFAULT_DOMAIN $DEFAULT_HOSTNAME
$DEFAULT_CLIENT_IP   ${DEFAULT_HOSTNAME/srv/clt}.$DEFAULT_DOMAIN
EOF
}

restart_network() {
    log_info "Restarting network services"
    systemctl restart NetworkManager
}