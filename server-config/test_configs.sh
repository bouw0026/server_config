#!/bin/bash

source "$(dirname "$0")/config.sh"

test_network() {
    log_info "Testing network configuration..."
    
    # Test hostname
    if [ "$(hostname)" != "$DEFAULT_HOSTNAME" ]; then
        log_error "Hostname test failed (Expected: $DEFAULT_HOSTNAME, Actual: $(hostname))"
        return 1
    fi
    
    # Test IP configuration
    if ! ip a show $DEFAULT_INTERFACE | grep -q $DEFAULT_SERVER_IP; then
        log_error "IP address test failed (Expected: $DEFAULT_SERVER_IP)"
        return 1
    fi
    
    log_success "Network configuration tests passed"
    return 0
}

test_ssh() {
    log_info "Testing SSH configuration..."
    
    # Test SSH port
    if ! ss -tuln | grep -q ":$DEFAULT_SSH_PORT"; then
        log_error "SSH port test failed (Expected: $DEFAULT_SSH_PORT)"
        return 1
    fi
    
    # Test SSH key authentication
    if ! grep -q "PubkeyAuthentication yes" /etc/ssh/sshd_config; then
        log_error "SSH key authentication test failed"
        return 1
    fi
    
    log_success "SSH configuration tests passed"
    return 0
}

test_firewall() {
    log_info "Testing firewall configuration..."
    
    # Test firewall rules
    if ! iptables -L INPUT -n | grep -q "tcp dpt:$DEFAULT_SSH_PORT"; then
        log_error "Firewall SSH port rule test failed"
        return 1
    fi
    
    log_success "Firewall configuration tests passed"
    return 0
}

test_dns() {
    log_info "Testing DNS configuration..."
    
    # Test DNS service
    if ! systemctl is-active --quiet named; then
        log_error "DNS service test failed (named not running)"
        return 1
    fi
    
    # Test DNS resolution
    if ! dig $DEFAULT_FQDN @localhost | grep -q "ANSWER: 1"; then
        log_error "DNS resolution test failed for $DEFAULT_FQDN"
        return 1
    fi
    
    log_success "DNS configuration tests passed"
    return 0
}

test_all() {
    local errors=0
    
    test_network || errors=$((errors + 1))
    test_ssh || errors=$((errors + 1))
    test_firewall || errors=$((errors + 1))
    test_dns || errors=$((errors + 1))
    
    if [ $errors -eq 0 ]; then
        log_success "All configuration tests passed successfully"
    else
        log_error "$errors configuration tests failed"
    fi
    
    return $errors
}
