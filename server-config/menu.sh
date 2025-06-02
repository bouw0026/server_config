#!/bin/bash

source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/network.sh"
source "$(dirname "$0")/ssh.sh"
source "$(dirname "$0")/firewall.sh"
source "$(dirname "$0")/dns.sh"

# Terminal layout configurations
configure_terminals() {
    if command -v tmux &> /dev/null; then
        tmux new-session -d -s server-config
        tmux split-window -h
        tmux split-window -v
        tmux select-pane -t 0
        tmux send-keys "watch -n 1 'systemctl status sshd named'" C-m
        tmux select-pane -t 1
        tmux send-keys "tail -f /var/log/server-config.log" C-m
        tmux select-pane -t 2
        tmux attach-session -t server-config
    else
        echo "tmux not found. Please install tmux for multi-terminal support."
        exit 1
    fi
}

# CST8246 specific configurations
configure_cst8246() {
    # Network configuration
    configure_network "ens224"
    set_hostname "srv1.example25.lab"
    
    # SSH hardening
    configure_ssh 2222 "admin"
    setup_key_auth
    
    # Firewall rules for lab environment
    configure_firewall "172.16.31.0/24" "172.16.30.0/24" 2222
    
    # DNS for lab domain
    configure_dns "example25.lab" "172.16.30.25"
}

# Main menu
show_menu() {
    clear
    echo "=== Server Configuration Menu ==="
    echo "1. Configure All Services"
    echo "2. CST8246 Lab Configuration"
    echo "3. Network Configuration"
    echo "4. SSH Configuration"
    echo "5. Firewall Configuration"
    echo "6. DNS Configuration"
    echo "7. View Logs"
    echo "8. System Status"
    echo "9. Exit"
    echo "10. Test All Configurations"
    echo "11. Create and Deploy Client Configurations"
    echo "=========================="
}

# Interactive menu loop
menu_loop() {
    while true; do
        show_menu
        read -p "Enter your choice [1-9]: " choice
        
        case $choice in
            1)
                configure_terminals
                configure_all
                ;;
            2)
                configure_terminals
                configure_cst8246
                ;;
            3)
                configure_network
                ;;
            4)
                read -p "Enter SSH port [2222]: " ssh_port
                configure_ssh "${ssh_port:-2222}"
                ;;
            5)
                configure_firewall
                ;;
            6)
                read -p "Enter domain name [example25.lab]: " domain
                configure_dns "${domain:-example25.lab}"
                ;;
            7)
                less /var/log/server-config.log
                ;;
            8)
                watch -n 1 'systemctl status sshd named'
                ;;
            9)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option"
                sleep 2
                ;;
        esac
    done
}

# Start the menu system
check_root
load_config
menu_loop
