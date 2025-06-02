#!/bin/bash

source "$(dirname "$0")/config.sh"

CLIENT_TEMPLATE_DIR="/etc/server-config/client-templates"
CLIENT_SCRIPT="client_setup.sh"

generate_client_config() {
    local client_id=$1
    local client_ip="${DEFAULT_CLIENT_IP%.*}.$client_id"
    local client_hostname="clt${client_id}"
    
    mkdir -p "$CLIENT_TEMPLATE_DIR"
    
    # Generate client network config
    cat > "$CLIENT_TEMPLATE_DIR/ifcfg-${client_hostname}" << EOF
DEVICE=ens224
BOOTPROTO=static
IPADDR=$client_ip
NETMASK=255.255.255.0
GATEWAY=${DEFAULT_SERVER_IP}
DNS1=${DEFAULT_SERVER_IP}
DNS2=8.8.8.8
ONBOOT=yes
EOF

    # Generate client hosts file
    cat > "$CLIENT_TEMPLATE_DIR/hosts-${client_hostname}" << EOF
127.0.0.1   localhost localhost.localdomain
$DEFAULT_SERVER_IP   $DEFAULT_FQDN $DEFAULT_HOSTNAME
$client_ip   ${client_hostname}.$DEFAULT_DOMAIN $client_hostname
EOF

    # Generate client setup script
    cat > "$CLIENT_SCRIPT" << EOF
#!/bin/bash

# Set hostname
hostnamectl set-hostname ${client_hostname}.$DEFAULT_DOMAIN

# Configure network
cp /etc/sysconfig/network-scripts/ifcfg-ens224 /etc/sysconfig/network-scripts/ifcfg-ens224.bak
cat > /etc/sysconfig/network-scripts/ifcfg-ens224 << NET_EOF
$(cat "$CLIENT_TEMPLATE_DIR/ifcfg-${client_hostname}")
NET_EOF

# Update hosts file
cp /etc/hosts /etc/hosts.bak
cat > /etc/hosts << HOSTS_EOF
$(cat "$CLIENT_TEMPLATE_DIR/hosts-${client_hostname}")
HOSTS_EOF

# Configure SSH
mkdir -p /home/admin/.ssh
chmod 700 /home/admin/.ssh
cat >> /home/admin/.ssh/authorized_keys << SSH_EOF
$(cat "$DEFAULT_SSH_KEY_PATH.pub")
SSH_EOF
chmod 600 /home/admin/.ssh/authorized_keys
chown -R admin:admin /home/admin/.ssh

# Restart network
systemctl restart NetworkManager

# Install packages
dnf install -y bind-utils
EOF

    chmod +x "$CLIENT_SCRIPT"
    log_info "Generated configuration for client $client_hostname ($client_ip)"
}

deploy_to_client() {
    local client_id=$1
    local client_ip="${DEFAULT_CLIENT_IP%.*}.$client_id"
    local client_hostname="clt${client_id}"
    
    generate_client_config "$client_id"
    
    log_info "Deploying configuration to client $client_hostname ($client_ip)"
    
    # Temporarily enable password auth for initial setup
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    # Copy setup script to client
    sshpass -p "password" scp -o StrictHostKeyChecking=no -P $DEFAULT_SSH_PORT "$CLIENT_SCRIPT" admin@$client_ip:/tmp/
    sshpass -p "password" ssh -o StrictHostKeyChecking=no -p $DEFAULT_SSH_PORT admin@$client_ip "sudo /tmp/$CLIENT_SCRIPT"
    
    # Disable password auth
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    log_success "Successfully deployed configuration to client $client_hostname"
}

create_multiple_clients() {
    read -p "Enter number of clients to create: " num_clients
    read -p "Enter starting client ID (e.g., 1): " start_id
    
    for ((i=start_id; i<start_id+num_clients; i++)); do
        deploy_to_client $i
    done
}
