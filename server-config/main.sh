#!/bin/bash

source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/network.sh"
source "$(dirname "$0")/ssh.sh"
source "$(dirname "$0")/firewall.sh"
source "$(dirname "$0")/dns.sh"

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --all                Configure all services"
    echo "  --dns-only           Configure only DNS"
    echo "  --ssh-only           Configure only SSH"
    echo "  --port PORT          Specify SSH port"
    echo "  --domain DOMAIN      Specify domain name"
}

main() {
    check_root
    load_config
    
    case "$1" in
        --all)
            configure_network
            set_hostname
            update_hosts
            configure_ssh
            configure_firewall
            configure_dns
            restart_network
            ;;
        --dns-only)
            configure_dns "$2"
            ;;
        --ssh-only)
            configure_ssh "$2"
            ;;
        *)
            print_usage
            exit 1
            ;;
    esac
}

main "$@"