#!/bin/bash

source "$(dirname "$0")/config.sh"

configure_dns() {
    local domain="${1:-$DEFAULT_DOMAIN}"
    local server_ip="${2:-$DEFAULT_SERVER_IP}"
    
    log_info "Configuring DNS server"
    
    # Install BIND
    dnf install -y bind bind-utils
    
    # Configure named.conf
    backup_file "/etc/named.conf"
    cat > "/etc/named.conf" << EOF
options {
    listen-on port 53 { 127.0.0.1; $server_ip; };
    directory "/var/named";
    allow-query { localhost; 172.16.30.0/24; 172.16.31.0/24; };
    recursion yes;
    forwarders { 8.8.8.8; 8.8.4.4; };
};

zone "$domain" IN {
    type master;
    file "/var/named/$domain.zone";
};
EOF

    # Create zone file
    cat > "/var/named/$domain.zone" << EOF
\$TTL 86400
@   IN  SOA     $DEFAULT_HOSTNAME.$domain. admin.$domain. (
                    $(date +%Y%m%d01) ; Serial
                    3600    ; Refresh
                    1800    ; Retry
                    604800  ; Expire
                    86400   ; Minimum TTL
)
@       IN  NS      $DEFAULT_HOSTNAME.$domain.
$DEFAULT_HOSTNAME   IN  A       $server_ip
EOF

    systemctl enable --now named
    systemctl restart named
    
    log_info "DNS server configured"
}