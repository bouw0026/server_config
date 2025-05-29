#!/usr/bin/env python3
"""
System Update Module

Handles:
- Package updates
- System upgrades
"""

from ..utils import run_cmd, check_root

class SystemUpdate:
    def __init__(self):
        self.updates_available = False

    def check_updates(self) -> bool:
        """Check for available updates"""
        print("\nChecking for system updates...")
        success, output = run_cmd("yum check-update")
        
        # yum returns 100 when updates are available
        self.updates_available = success and bool(output)
        
        if self.updates_available:
            print("Updates available:")
            print(output)
        else:
            print("System is up to date")
            
        return self.updates_available

    def run_updates(self) -> bool:
        """Run system updates"""
        print("\nRunning system updates...")
        success, output = run_cmd("yum update -y", sudo=True)
        
        if not success:
            raise Exception(f"Update failed: {output}")
        
        print("System updates completed successfully")
        return True

    def configure(self) -> bool:
        """Run complete update process"""
        check_root()
        self.check_updates()
        
        if self.updates_available:
            return self.run_updates()
        return True

# Module-level functions
def run_updates() -> bool:
    """Run system updates"""
    return SystemUpdate().configure()

def check_updates() -> bool:
    """Check for available updates"""
    return SystemUpdate().check_updates()