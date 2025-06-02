#!/bin/bash

# Set repository URL
REPO_URL="https://github.com/bouw0026/server_config.git"
CONFIG_DIR="/etc/server-config"

# Create configuration directory
mkdir -p "$CONFIG_DIR"
chown -R root:root "$CONFIG_DIR"
chmod 750 "$CONFIG_DIR"

# Clone repository (sparse checkout for just server-config directory)
cd "$CONFIG_DIR" || exit 1
git init
git remote add origin "$REPO_URL"
git config core.sparseCheckout true
echo "server-config/*" >> .git/info/sparse-checkout
git pull origin main

# Set up required directory structure
mkdir -p "$CONFIG_DIR/backups"
mkdir -p /var/log
touch /var/log/server-config.log
chmod 644 /var/log/server-config.log

# Set proper permissions for scripts
chmod 750 "$CONFIG_DIR"/*.sh

# Verify and start the menu
if [[ -f "$CONFIG_DIR/menu.sh" ]]; then
    cd "$CONFIG_DIR" || exit 1
    ./menu.sh
else
    echo "Error: menu.sh not found in $CONFIG_DIR"
    exit 1
fi
