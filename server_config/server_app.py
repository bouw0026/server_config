#!/usr/bin/env python3
"""
Server Configuration Application

A unified interface for all server configuration tasks.
"""

import argparse
from .server_module import dns, ssh, firewall, network, system
from .server_module.utils import run_cmd

def configure_all(args):
    """Run all configuration steps"""
    print("=== Starting Complete Server Configuration ===")
    
    # 1. System registration and updates
    if args.username and args.password:
        print("\n[1/5] Registering system and running updates...")
        system.register_system(args.username, args.password)
        system.run_updates()
    else:
        print("\n[1/5] Skipping system registration (no credentials provided)")
    
    # 2. Network configuration
    print("\n[2/5] Configuring network interfaces...")
    net_config = network.configure_interfaces()
    
    # 3. Firewall configuration
    print("\n[3/5] Configuring firewall rules...")
    firewall.configure_iptables(
        client_net=args.client_net or "172.16.31.0/24",
        server_net=args.server_net or "172.16.30.0/24",
        port=args.port or 22
    )
    
    # 4. SSH configuration
    print("\n[4/5] Configuring SSH server...")
    ssh.configure_ssh(
        port=args.port or 22,
        red_ip=net_config.get('red_ip'),
        alias_ip=net_config.get('alias_ip')
    )
    ssh.setup_key_auth()
    
    # 5. DNS configuration
    print("\n[5/5] Configuring DNS server...")
    dns.configure_dns(
        domain=args.domain or "example25.lab",
        server_ip=net_config.get('server_ip')
    )
    
    print("\n=== Server Configuration Complete ===")

def main():
    parser = argparse.ArgumentParser(description='Server Configuration Tool')
    
    # System registration
    parser.add_argument('--username', help='Red Hat subscription username')
    parser.add_argument('--password', help='Red Hat subscription password')
    
    # Network configuration
    parser.add_argument('--domain', help='Domain name for DNS configuration')
    
    # Firewall configuration
    parser.add_argument('--client-net', help='Client network to allow')
    parser.add_argument('--server-net', help='Server network to deny')
    parser.add_argument('--port', type=int, help='Port number for services')
    
    # Execution mode
    parser.add_argument('--all', action='store_true', 
                       help='Run all configuration steps')
    parser.add_argument('--dns-only', action='store_true', 
                       help='Configure only DNS')
    parser.add_argument('--ssh-only', action='store_true', 
                       help='Configure only SSH')
    
    args = parser.parse_args()
    
    if args.all:
        configure_all(args)
    elif args.dns_only:
        dns.configure_dns(domain=args.domain)
    elif args.ssh_only:
        ssh.configure_ssh(port=args.port)
    else:
        print("Please specify an operation mode (--all, --dns-only, --ssh-only)")
        parser.print_help()

if __name__ == "__main__":
    main()