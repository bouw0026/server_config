#!/bin/bash

source "$(dirname "$0")/config.sh"

configure_firewall() {
    local client_net="${1:-172.16.31.0/24}"
    local server_net="${2:-172.16.30.0/24}"
    local port="${3:-$DEFAULT_SSH_PORT}"
    
    log_info "Configuring firewall rules"
    
    # Backup current rules
    iptables-save > "${BACKUP_DIR}/iptables.bak.$(date +%Y%m%d_%H%M%S)"
    
    # Reset rules
    iptables -F
    
    # Configure rules
    iptables -A INPUT -p tcp --dport "$port" -s "$client_net" -j ACCEPT
    iptables -A INPUT -p tcp --dport "$port" -s "$server_net" -j REJECT
    
    # Save rules
    service iptables save
    
    log_info "Firewall configured"
}