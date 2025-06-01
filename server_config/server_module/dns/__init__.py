"""
DNS Configuration Submodule

Handles:
- BIND9 installation and configuration
- Zone file creation
- DNS testing
"""

from .setup import configure_dns, test_dns, create_zone_files

__all__ = ['configure_dns', 'test_dns', 'create_zone_files']