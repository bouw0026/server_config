#!/usr/bin/env python3
"""
SSH Server Configuration Module

Handles:
- SSH server configuration
- Key-based authentication
- Firewall rules
"""

from ..utils import run_cmd, backup_file, check_root
from ..config import DEFAULT_SSH
from datetime import datetime
import os

class SSHConfig:
    def __init__(self, port: int = None, user: str = None):
        self.port = port or DEFAULT_SSH.port
        self.user = user or DEFAULT_SSH.user
        self.key_path = DEFAULT_SSH.key_path
        self.red_interface = DEFAULT_SSH.red_interface
        self.alias_ip = DEFAULT_SSH.alias_ip
        self.client_ip = DEFAULT_SSH.client_ip
        self.ssh_config = "/etc/ssh/sshd_config"
        self.backup_dir = "/etc/ssh/backups"

    def configure_network(self) -> Tuple[str, str]:
        """Configure network interfaces for SSH"""
        print("\n=== Network Interface Setup ===")
        
        # Get primary IP
        success, red_ip = run_cmd(
            f"ip -4 addr show {self.red_interface} | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){{3}}'", 
            sudo=True
        )
        if not success:
            raise Exception(f"Could not get IP for {self.red_interface}")
        
        red_ip = red_ip.strip()
        aliased_if = f"{self.red_interface}:1"
        
        # Create alias
        run_cmd(
            f"ip addr add {self.alias_ip}/24 dev {self.red_interface} label {aliased_if}", 
            sudo=True
        )
        
        print(f"Configured:\n- Primary: {self.red_interface} ({red_ip})\n- Alias: {aliased_if} ({self.alias_ip})")
        return red_ip, self.alias_ip

    def configure_ssh_server(self, red_ip: str, alias_ip: str) -> bool:
        """Configure SSH server settings"""
        print("\n=== SSH Server Configuration ===")
        
        # Backup config
        if not os.path.exists(self.backup_dir):
            os.makedirs(self.backup_dir, exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_path = f"{self.backup_dir}/{os.path.basename(self.ssh_config)}.bak.{timestamp}"
        run_cmd(f"cp {self.ssh_config} {backup_path}", sudo=True)
        print(f"Backup created at {backup_path}")

        # Configuration changes
        config_changes = [
            f"Port {self.port}",
            f"ListenAddress {red_ip}",
            f"ListenAddress {alias_ip}",
            "PermitRootLogin no",
            "PasswordAuthentication no",
            "PubkeyAuthentication yes",
            "X11Forwarding no",
            f"AllowUsers {self.user}"
        ]
        
        # Apply changes
        for line in config_changes:
            key = line.split()[0]
            run_cmd(
                f"grep -q '^{key}' {self.ssh_config} && "
                f"sed -i 's/^#*{key}.*/{line}/' {self.ssh_config} || "
                f"echo '{line}' >> {self.ssh_config}", 
                sudo=True
            )
        
        # Restart SSH
        run_cmd("systemctl restart sshd", sudo=True)
        print("SSH configuration updated successfully")
        return True

    def configure_firewall(self) -> bool:
        """Configure firewall rules for SSH"""
        print("\n=== Firewall Configuration ===")
        
        # Flush existing rules
        run_cmd("iptables -F", sudo=True)
        
        # Allow client subnet
        run_cmd(
            f"iptables -A INPUT -p tcp --dport {self.port} -s {DEFAULT_SSH.client_subnet} -j ACCEPT",
            sudo=True
        )
        
        # Reject server subnet
        run_cmd(
            f"iptables -A INPUT -p tcp --dport {self.port} -s {DEFAULT_SSH.server_subnet} -j REJECT",
            sudo=True
        )
        
        # Save rules
        run_cmd("service iptables save", sudo=True)
        
        print("Firewall rules configured:")
        run_cmd("iptables -L -n --line-numbers", sudo=True)
        return True

    def setup_key_auth(self) -> bool:
        """Set up key-based authentication"""
        print("\n=== Key-Based Auth Setup ===")
        
        # Generate key if not exists
        if not os.path.exists(self.key_path):
            run_cmd(f"ssh-keygen -t rsa -b 4096 -f {self.key_path} -N ''")
        
        # Transfer key to client
        print(f"Transferring key to client ({self.client_ip})...")
        success, _ = run_cmd(f"ssh-copy-id -i {self.key_path}.pub {self.user}@{self.client_ip}")
        
        if not success:
            print("\nManual key copy required. Add this to client's ~/.ssh/authorized_keys:")
            with open(f"{self.key_path}.pub", "r") as f:
                print(f.read().strip())
            return False
        
        # Secure client SSH config
        client_commands = [
            "sudo sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config",
            "sudo systemctl restart sshd"
        ]
        
        for cmd in client_commands:
            run_cmd(f'ssh {self.user}@{self.client_ip} "{cmd}"')
        
        print("Key authentication configured successfully")
        return True

    def configure(self) -> bool:
        """Run complete SSH configuration"""
        check_root()
        red_ip, alias_ip = self.configure_network()
        self.configure_ssh_server(red_ip, alias_ip)
        self.configure_firewall()
        self.setup_key_auth()
        return True

# Module-level functions
def configure_ssh(port: int = None, user: str = None) -> bool:
    """Configure SSH server with optional overrides"""
    return SSHConfig(port, user).configure()

def verify_ssh_config() -> bool:
    """Verify SSH configuration"""
    ssh = SSHConfig()
    checks = [
        ("SSH listening on interfaces", 
         f"ss -tlnp | grep 'sshd.*:{ssh.port}'"),
        ("Firewall allows client subnet",
         f"iptables -L -n | grep 'ACCEPT.*{DEFAULT_SSH.client_subnet}.*dpt:{ssh.port}'"),
        ("Firewall rejects server subnet",
         f"iptables -L -n | grep 'REJECT.*{DEFAULT_SSH.server_subnet}.*dpt:{ssh.port}'"),
        ("Root login disabled",
         "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config")
    ]
    
    for desc, cmd in checks:
        success, _ = run_cmd(cmd, sudo=True)
        print(f"{'✓' if success else '✗'} {desc}")
        if not success:
            return False
    return True