#!/bin/bash

# Configuration variables
CONFIG_FILE="/etc/server-config/config.yaml"
BACKUP_DIR="/etc/server-config/backups"
LOG_FILE="/var/log/server-config.log"

# CST8246 specific defaults
DEFAULT_INTERFACE="ens224"
DEFAULT_SERVER_IP="172.16.30.25"
DEFAULT_CLIENT_IP="172.16.31.25"
DEFAULT_ALIAS_IP="172.16.32.25"
DEFAULT_DOMAIN="example25.lab"
DEFAULT_HOSTNAME="srv1"
DEFAULT_FQDN="srv1.example25.lab"

# SSH defaults for lab environment
DEFAULT_SSH_PORT=2222
DEFAULT_SSH_USER="admin"
DEFAULT_SSH_KEY_PATH="/home/admin/.ssh/id_rsa"

# Logging functions with timestamps
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a "$LOG_FILE"
}

# Enhanced root check with sudo support
check_root() {
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            log_info "Attempting to escalate privileges using sudo..."
            exec sudo "$0" "$@"
        else
            log_error "This script must be run as root"
            exit 1
        fi
    fi
}

# Backup function with compression
backup_file() {
    local file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup="${BACKUP_DIR}/$(basename "$file").bak.${timestamp}.gz"
    
    mkdir -p "$BACKUP_DIR"
    if [[ -f "$file" ]]; then
        gzip -c "$file" > "$backup"
        log_info "Backup created: $backup"
    else
        log_error "File not found: $file"
        return 1
    fi
}

# Configuration validation
validate_config() {
    local errors=0
    
    # Validate IP addresses
    if ! [[ $DEFAULT_SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid server IP: $DEFAULT_SERVER_IP"
        ((errors++))
    fi
    
    # Validate port number
    if ! [[ $DEFAULT_SSH_PORT =~ ^[0-9]+$ ]] || [ $DEFAULT_SSH_PORT -lt 1 ] || [ $DEFAULT_SSH_PORT -gt 65535 ]; then
        log_error "Invalid SSH port: $DEFAULT_SSH_PORT"
        ((errors++))
    fi
    
    return $errors
}

# Load and validate configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        validate_config
    else
        log_info "No config file found, using defaults"
        validate_config
    fi
}