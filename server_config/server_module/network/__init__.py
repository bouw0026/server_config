"""
Network Configuration Submodule

Handles:
- Interface configuration
- Hostname setup
- /etc/hosts management
"""

from .setup import (configure_interfaces,
                   set_hostname,
                   update_hosts_file,
                   restart_network)

__all__ = ['configure_interfaces', 'set_hostname', 'update_hosts_file', 'restart_network']