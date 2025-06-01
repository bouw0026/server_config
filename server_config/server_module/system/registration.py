#!/usr/bin/env python3
"""
System Registration Module

Handles:
- Red Hat subscription
- System registration
"""

from ..utils import run_cmd, check_root
from typing import Tuple
import getpass

class SystemRegistration:
    def __init__(self, username: str = None, password: str = None):
        self.username = username
        self.password = password

    def check_registration(self) -> bool:
        """Check if system is already registered"""
        success, _ = run_cmd("subscription-manager identity")
        return success

    def register_system(self) -> bool:
        """Register system with Red Hat"""
        if not self.username or not self.password:
            raise ValueError("Username and password required for registration")
        
        print("\nRegistering system with Red Hat...")
        
        cmd = f"subscription-manager register --username {self.username} --password {self.password}"
        success, output = run_cmd(cmd, sudo=True)
        
        if not success:
            raise Exception(f"Registration failed: {output}")
        
        print("System registered successfully")
        return True

    def refresh_subscription(self) -> bool:
        """Refresh subscription data"""
        print("\nRefreshing subscription data...")
        success, output = run_cmd("subscription-manager refresh", sudo=True)
        
        if not success:
            print(f"Warning: Could not refresh subscription: {output}")
            return False
        
        print("Subscription data refreshed")
        return True

    def configure(self) -> bool:
        """Run complete registration process"""
        check_root()
        
        if self.check_registration():
            print("System is already registered")
            return True
            
        if not self.username:
            self.username = input("Enter Red Hat username: ")
        if not self.password:
            self.password = getpass.getpass("Enter Red Hat password: ")
        
        self.register_system()
        self.refresh_subscription()
        return True

# Module-level functions
def register_system(username: str = None, password: str = None) -> bool:
    """Register system with Red Hat"""
    return SystemRegistration(username, password).configure()

def check_registration() -> bool:
    """Check registration status"""
    return SystemRegistration().check_registration()