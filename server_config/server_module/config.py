#!/usr/bin/env python3
"""
Server Configuration Constants and Defaults

Centralized configuration for all server modules with:
- Environment detection
- Default values
- Network constants
"""

import os
import socket
from dataclasses import dataclass
from typing import List, Dict

@dataclass
class NetworkConfig:
    """Network-related configuration"""
    interface: str = "ens224"
    server_ip: str = "172.16.30.25"
    client_ip: str = "172.16.31.25"
    alias_ip: str = "172.16.32.25"
    domain: str = "example25.lab"
    hostname: str = "server-node"
    fqdn: str = "server-node.example25.lab"
    dns_port: int = 53
    ssh_port: int = 22
    client_subnet: str = "172.16.31.0/24"
    server_subnet: str = "172.16.30.0/24"
    allowed_networks: List[str] = None
    
    def __post_init__(self):
        if self.allowed_networks is None:
            self.allowed_networks = [self.client_subnet, self.server_subnet]

@dataclass
class SSHConfig:
    """SSH-specific configuration"""
    user: str = "admin"
    key_path: str = "/home/admin/.ssh/id_rsa"
    red_interface: str = "ens224"
    alias_ip: str = "172.16.32.25"
    client_ip: str = "172.16.31.25"
    port: int = 22
    backup_dir: str = "/etc/ssh/backups"

@dataclass 
class ServiceConfig:
    """Service management configuration"""
    dns_zone_dir: str = "/var/named"
    named_conf: str = "/etc/named.conf"
    sshd_config: str = "/etc/ssh/sshd_config"
    firewall_backup_dir: str = "/etc/iptables/backups"

def detect_environment() -> Dict:
    """Auto-detect server environment settings"""
    config = {
        "hostname": socket.gethostname(),
        "fqdn": socket.getfqdn(),
        "domain": ".".join(socket.getfqdn().split('.')[1:]) if '.' in socket.getfqdn() else "localdomain",
        "interfaces": []
    }
    
    try:
        # Detect primary IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        config["server_ip"] = s.getsockname()[0]
        s.close()
    except:
        config["server_ip"] = "127.0.0.1"
    
    return config

# Environment-aware configuration
env_config = detect_environment()

# Default configurations
DEFAULT_NETWORK = NetworkConfig(
    hostname=env_config["hostname"],
    fqdn=env_config["fqdn"],
    domain=env_config["domain"],
    server_ip=env_config["server_ip"]
)

DEFAULT_SSH = SSHConfig()
DEFAULT_SERVICE = ServiceConfig()

# Current active configuration
ACTIVE_CONFIG = {
    "network": DEFAULT_NETWORK,
    "ssh": DEFAULT_SSH,
    "services": DEFAULT_SERVICE
}

def update_config(module: str, **kwargs):
    """
    Dynamically update configuration for a module
    
    Args:
        module: One of 'network', 'ssh', or 'services'
        kwargs: Configuration attributes to update
    """
    if module not in ACTIVE_CONFIG:
        raise ValueError(f"Invalid module {module}. Must be one of {list(ACTIVE_CONFIG.keys())}")
    
    for key, value in kwargs.items():
        if hasattr(ACTIVE_CONFIG[module], key):
            setattr(ACTIVE_CONFIG[module], key, value)
        else:
            raise AttributeError(f"{module} config has no attribute {key}")