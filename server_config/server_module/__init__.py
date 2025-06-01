"""
Server Configuration Module

A comprehensive module for configuring Linux servers with:
- DNS setup
- SSH configuration
- Firewall rules
- Network setup
- System registration and updates
"""

from .config import NetworkConfig, SSHConfig, DEFAULT_NETWORK, DEFAULT_SSH
from .utils import run_cmd, backup_file, check_root

__version__ = "1.0.0"
__all__ = ['dns', 'ssh', 'firewall', 'network', 'system']