#!/usr/bin/env python3
"""
Firewall Configuration Module

Handles:
- iptables installation
- Rule management
- Subnet filtering
"""

from ..utils import run_cmd, backup_file, check_root
from ..config import DEFAULT_NETWORK
from typing import Tuple, List
import time

class FirewallConfig:
    def __init__(self, client_net: str = None, server_net: str = None, port: int = None):
        self.client_net = client_net or "172.16.31.0/24"
        self.server_net = server_net or "172.16.30.0/24"
        self.port = port or 22
        self.backup_dir = "/etc/iptables/backups"

    def install_iptables(self) -> bool:
        """Install iptables services if not present"""
        print("\nChecking for iptables installation...")
        
        # Check if installed
        success, _ = run_cmd("rpm -q iptables-services")
        if success:
            print("iptables-services already installed")
            return True
        
        print("Installing iptables...")
        run_cmd("dnf install -y iptables-services", sudo=True)
        run_cmd("systemctl enable iptables", sudo=True)
        run_cmd("systemctl start iptables", sudo=True)
        return True

    def backup_rules(self) -> str:
        """Backup current iptables rules"""
        print("\nBacking up current rules...")
        
        if not os.path.exists(self.backup_dir):
            os.makedirs(self.backup_dir, exist_ok=True)
        
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        backup_file = f"{self.backup_dir}/iptables.bak.{timestamp}"
        run_cmd(f"iptables-save > {backup_file}", sudo=True)
        
        print(f"Rules backed up to {backup_file}")
        return backup_file

    def flush_rules(self) -> bool:
        """Flush existing iptables rules"""
        print("\nFlushing existing rules...")
        run_cmd("iptables -F", sudo=True)
        run_cmd("iptables -P INPUT ACCEPT", sudo=True)
        run_cmd("iptables -P FORWARD ACCEPT", sudo=True)
        run_cmd("iptables -P OUTPUT ACCEPT", sudo=True)
        return True

    def configure_rules(self) -> bool:
        """Configure firewall rules"""
        print(f"\nConfiguring rules for port {self.port}")
        print(f"  Allowed: {self.client_net}")
        print(f"  Denied: {self.server_net}")
        
        # Allow client network
        run_cmd(
            f"iptables -A INPUT -p tcp --dport {self.port} -s {self.client_net} -j ACCEPT",
            sudo=True
        )
        
        # Deny server network
        run_cmd(
            f"iptables -A INPUT -p tcp --dport {self.port} -s {self.server_net} -j REJECT",
            sudo=True
        )
        
        return True

    def save_rules(self) -> bool:
        """Save rules for persistence"""
        print("\nSaving rules...")
        run_cmd("service iptables save", sudo=True)
        
        print("\nCurrent rules:")
        run_cmd("iptables -L -n -v", sudo=True)
        return True

    def configure(self) -> bool:
        """Run complete firewall configuration"""
        check_root()
        self.install_iptables()
        self.backup_rules()
        self.flush_rules()
        self.configure_rules()
        self.save_rules()
        return True

# Module-level functions
def configure_iptables(client_net: str = None, server_net: str = None, port: int = None) -> bool:
    """Configure iptables with optional parameters"""
    return FirewallConfig(client_net, server_net, port).configure()

def backup_rules() -> str:
    """Backup current rules"""
    return FirewallConfig().backup_rules()

def flush_rules() -> bool:
    """Flush all rules"""
    return FirewallConfig().flush_rules()