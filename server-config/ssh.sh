#!/bin/bash

source "$(dirname "$0")/config.sh"

configure_ssh() {
    local port="${1:-$DEFAULT_SSH_PORT}"
    local user="${2:-$DEFAULT_SSH_USER}"
    
    log_info "Configuring SSH server"
    backup_file "/etc/ssh/sshd_config"
    
    # Configure sshd
    cat > "/etc/ssh/sshd_config" << EOF
Port $port
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
AllowUsers $user
EOF

    systemctl restart sshd
}

setup_key_auth() {
    local key_path="${1:-$DEFAULT_SSH_KEY_PATH}"
    
    if [[ ! -f "$key_path" ]]; then
        ssh-keygen -t rsa -b 4096 -f "$key_path" -N ''
    fi
    
    log_info "Key authentication configured"
}