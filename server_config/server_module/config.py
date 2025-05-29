#!/usr/bin/env python3
"""
Server Configuration Constants and Defaults

Centralized configuration management with YAML support
"""

import os
import socket
import yaml
from dataclasses import dataclass
from typing import List, Dict

def load_config() -> Dict:
    """Load configuration from YAML file"""
    config_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'config.yaml')
    try:
        with open(config_file, 'r') as f:
            return yaml.safe_load(f)
    except (FileNotFoundError, yaml.YAMLError):
        return {}

# Load configuration
CONFIG = load_config()

@dataclass
class NetworkConfig:
    """Network-related configuration"""
    interface: str = CONFIG.get('network', {}).get('interface', 'ens224')
    server_ip: str = CONFIG.get('network', {}).get('server_ip', '172.16.30.25')
    client_ip: str = CONFIG.get('network', {}).get('client_ip', '172.16.31.25')
    alias_ip: str = CONFIG.get('network', {}).get('alias_ip', '172.16.32.25')
    domain: str = CONFIG.get('network', {}).get('domain', 'example25.lab')
    hostname: str = CONFIG.get('network', {}).get('hostname', 'server-node')
    fqdn: str = f"{hostname}.{domain}"
    dns_port: int = CONFIG.get('dns', {}).get('port', 53)
    ssh_port: int = CONFIG.get('ssh', {}).get('port', 22)
    client_subnet: str = CONFIG.get('firewall', {}).get('client_subnet', '172.16.31.0/24')
    server_subnet: str = CONFIG.get('firewall', {}).get('server_subnet', '172.16.30.0/24')
    allowed_networks: List[str] = None
    
    def __post_init__(self):
        if self.allowed_networks is None:
            self.allowed_networks = [self.client_subnet, self.server_subnet]

@dataclass
class SSHConfig:
    """SSH-specific configuration"""
    user: str = CONFIG.get('ssh', {}).get('user', 'admin')
    key_path: str = CONFIG.get('ssh', {}).get('key_path', '/home/admin/.ssh/id_rsa')
    red_interface: str = CONFIG.get('ssh', {}).get('red_interface', 'ens224')
    alias_ip: str = CONFIG.get('network', {}).get('alias_ip', '172.16.32.25')
    client_ip: str = CONFIG.get('network', {}).get('client_ip', '172.16.31.25')
    port: int = CONFIG.get('ssh', {}).get('port', 22)
    backup_dir: str = "/etc/ssh/backups"

@dataclass 
class ServiceConfig:
    """Service management configuration"""
    dns_zone_dir: str = CONFIG.get('dns', {}).get('zone_dir', '/var/named')
    named_conf: str = CONFIG.get('dns', {}).get('config_file', '/etc/named.conf')
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
DEFAULT_NETWORK = NetworkConfig()
DEFAULT_SSH = SSHConfig()
DEFAULT_SERVICE = ServiceConfig()

# Current active configuration
ACTIVE_CONFIG = {
    "network": DEFAULT_NETWORK,
    "ssh": DEFAULT_SSH,
    "services": DEFAULT_SERVICE
}