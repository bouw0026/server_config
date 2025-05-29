"""
System Configuration Submodule

Handles:
- System registration
- Package updates
- Service management
"""

from .registration import register_system
from .updates import run_updates

__all__ = ['register_system', 'run_updates']