#!/bin/bash

# Configuration variables
CONFIG_FILE="/etc/server-config/config.yaml"
BACKUP_DIR="/etc/server-config/backups"
LOG_FILE="/var/log/server-config.log"

# Network defaults
DEFAULT_INTERFACE="ens224"
DEFAULT_SERVER_IP="172.16.30.25"
DEFAULT_CLIENT_IP="172.16.31.25"
DEFAULT_ALIAS_IP="172.16.32.25"
DEFAULT_DOMAIN="example25.lab"
DEFAULT_HOSTNAME="server-node"

# SSH defaults
DEFAULT_SSH_PORT=22
DEFAULT_SSH_USER="admin"
DEFAULT_SSH_KEY_PATH="/home/admin/.ssh/id_rsa"

# Logging functions
log_info() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Backup function
backup_file() {
    local file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup="${BACKUP_DIR}/$(basename "$file").bak.${timestamp}"
    
    mkdir -p "$BACKUP_DIR"
    cp "$file" "$backup"
    log_info "Backup created: $backup"
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        log_info "No config file found, using defaults"
    fi
}