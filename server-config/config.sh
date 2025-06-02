#!/bin/bash

# Configuration variables
# Use HOME environment variable to get the user's home directory
CONFIG_BASE_DIR="/home/cst8246/server-config"
CONFIG_FILE="$CONFIG_BASE_DIR/config.yaml"
BACKUP_DIR="$CONFIG_BASE_DIR/backups"
LOG_FILE="$CONFIG_BASE_DIR/server-config.log"

# CST8246 specific defaults (unchanged)
DEFAULT_INTERFACE="ens224"
DEFAULT_SERVER_IP="172.16.30.25"
DEFAULT_CLIENT_IP="172.16.31.25"
DEFAULT_ALIAS_IP="172.16.32.25"
DEFAULT_DOMAIN="example25.lab"
DEFAULT_HOSTNAME="bouw0026-srv"
DEFAULT_FQDN="bouw0026-srv.example25.lab"

# SSH defaults for lab environment (unchanged)
DEFAULT_SSH_PORT=2222
DEFAULT_SSH_USER="admin"
DEFAULT_SSH_KEY_PATH="/home/cst8246/.ssh/id_rsa" # Adjusted for user's home directory

# RHEL specific checks (unchanged - these still require root for subscription-manager)
check_rhel_subscription() {
    if ! subscription-manager status >/dev/null 2>&1; then
        log_error "System is not registered with Red Hat. Please register first."
        exit 1
    fi
}

# Install required packages (unchanged - these still require root for yum/dnf)
install_dependencies() {
    # It's highly recommended to use sudo for package installation if not already root
    sudo yum install -y epel-release || log_error "Failed to install epel-release"
    sudo yum install -y tmux gzip bind bind-utils || log_error "Failed to install dependencies"
}

# Logging functions with timestamps (unchanged logic, but log file path is now user-specific)
log_info() {
    mkdir -p "$(dirname "$LOG_FILE")" # Ensure log directory exists
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "$LOG_FILE"
}

log_error() {
    mkdir -p "$(dirname "$LOG_FILE")" # Ensure log directory exists
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "$LOG_FILE"
}

log_success() {
    mkdir -p "$(dirname "$LOG_FILE")" # Ensure log directory exists
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a "$LOG_FILE"
}

# Enhanced root check with sudo support (unchanged, but now `exec sudo "$0" "$@"` will re-run the script as root if needed)
check_root() {
    if [ "$EUID" -ne 0 ]; then
        if which sudo >/dev/null 2>&1; then
            log_info "Attempting to escalate privileges using sudo..."
            exec sudo "$0" "$@" # Re-execute the script with sudo
        else
            log_error "This script must be run as root"
            exit 1
        fi
    fi
}

# SELinux context handling (unchanged - these still require root for restorecon/chcon)
set_selinux_context() {
    local file="$1"
    local context="$2"
    if which restorecon >/dev/null 2>&1; then
        sudo restorecon -v "$file" # Use sudo for restorecon
    fi
    if [ -n "$context" ]; then
        sudo chcon "$context" "$file" # Use sudo for chcon
    fi
}

# Backup function with compression (adjusted mkdir -p to ensure backup directory exists for current user)
backup_file() {
    local file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup="${BACKUP_DIR}/$(basename "$file").bak.${timestamp}.gz"
    
    mkdir -p "$BACKUP_DIR" # Ensure the user's backup directory exists
    if [ -f "$file" ]; then
        # For sensitive system files like /etc/named.conf or /etc/ssh/sshd_config
        # the user running the script might not have read permissions without sudo.
        # You'll need to decide if these backups should be done with sudo or if
        # you only backup files the current user has access to.
        # For simplicity here, if you're intending to run these scripts as a regular user
        # and only elevate privileges for specific commands, you might need to
        # adjust where certain files are backed up or how.
        # If the script is generally expected to run with escalated privileges (via check_root),
        # then the existing gzip command will work for system files.
        gzip -c "$file" > "$backup"
        log_info "Backup created: $backup"
    else
        log_error "File not found: $file"
        return 1
    fi
}

# Configuration validation (unchanged)
validate_config() {
    local errors=0
    
    # Validate IP addresses
    if ! echo "$DEFAULT_SERVER_IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_error "Invalid server IP: $DEFAULT_SERVER_IP"
        errors=$((errors + 1))
    fi
    
    # Validate port number
    if ! echo "$DEFAULT_SSH_PORT" | grep -qE '^[0-9]+$' || [ "$DEFAULT_SSH_PORT" -lt 1 ] || [ "$DEFAULT_SSH_PORT" -gt 65535 ]; then
        log_error "Invalid SSH port: $DEFAULT_SSH_PORT"
        errors=$((errors + 1))
    fi
    
    return "$errors"
}

# Load and validate configuration (unchanged logic, but paths are now user-specific)
load_config() {
    # Note: check_rhel_subscription and install_dependencies will still require root.
    # If the script is run as a regular user, check_root should elevate it.
    check_rhel_subscription
    install_dependencies
    
    if [ -f "$CONFIG_FILE" ]; then
        # When sourcing a config file, make sure it's owned by the user and not executable
        . "$CONFIG_FILE"
        validate_config
    else
        log_info "No config file found, using defaults"
        validate_config
    fi
}
Explanation of Changes and Considerations:
