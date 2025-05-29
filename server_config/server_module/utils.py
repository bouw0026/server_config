#!/usr/bin/env python3
"""
Server Utilities Module

Common functions used across all server modules:
- Command execution
- File operations
- Validation
- Error handling
"""

import os
import sys
import subprocess
import shutil
from typing import Tuple, Optional, List, Union
from datetime import datetime
import logging

# Configure logging with fallback to current directory
try:
    log_dir = '/var/log'
    if not os.path.exists(log_dir) or not os.access(log_dir, os.W_OK):
        log_dir = os.path.dirname(os.path.dirname(__file__))
    log_file = os.path.join(log_dir, 'server_config.log')
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )
except Exception as e:
    # Fallback to console-only logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

logger = logging.getLogger(__name__)

class CommandError(Exception):
    """Custom exception for command execution failures"""
    def __init__(self, command: str, message: str, stderr: str = None):
        self.command = command
        self.message = message
        self.stderr = stderr
        super().__init__(f"{message}\nCommand: {command}\nError: {stderr}")

def run_cmd(
    command: Union[str, List[str]],
    sudo: bool = False,
    capture_output: bool = True,
    check: bool = True,
    timeout: int = 300
) -> Tuple[bool, str]:
    """
    Execute a shell command with robust error handling
    
    Args:
        command: Command string or list of args
        sudo: Run with sudo privileges
        capture_output: Return command output
        check: Raise exception on failure
        timeout: Command timeout in seconds
    
    Returns:
        Tuple of (success, output)
    
    Raises:
        CommandError: If check=True and command fails
    """
    # Handle dry run mode for testing
    if os.environ.get('SERVER_CONFIG_DRY_RUN'):
        logger.info(f"[DRY RUN] Would execute: {command}")
        return True, "dry-run"

    if sudo and os.geteuid() != 0:
        command = ["sudo"] + (command if isinstance(command, list) else command.split())
    elif isinstance(command, str):
        command = command.split()
    
    logger.debug(f"Executing: {' '.join(command)}")
    
    try:
        result = subprocess.run(
            command,
            check=check,
            stdout=subprocess.PIPE if capture_output else None,
            stderr=subprocess.PIPE if capture_output else None,
            universal_newlines=True,
            timeout=timeout
        )
        output = result.stdout.strip() if capture_output and result.stdout else ""
        return True, output
    
    except subprocess.CalledProcessError as e:
        error_msg = f"Command failed with exit code {e.returncode}"
        if check:
            raise CommandError(' '.join(command), error_msg, e.stderr.strip() if e.stderr else None)
        logger.warning(f"{error_msg}: {' '.join(command)}")
        return False, e.stderr.strip() if e.stderr else error_msg
    
    except subprocess.TimeoutExpired:
        error_msg = f"Command timed out after {timeout} seconds"
        if check:
            raise CommandError(' '.join(command), error_msg)
        logger.warning(f"{error_msg}: {' '.join(command)}")
        return False, error_msg
    
    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        if check:
            raise CommandError(' '.join(command), error_msg)
        logger.error(f"{error_msg}: {' '.join(command)}")
        return False, error_msg

def backup_file(file_path: str, backup_dir: str = None) -> Tuple[bool, Optional[str]]:
    """
    Create timestamped backup of a file
    
    Args:
        file_path: Path to file to backup
        backup_dir: Custom backup directory (defaults to same dir as original)
    
    Returns:
        Tuple of (success, backup_path)
    """
    if not os.path.exists(file_path):
        logger.error(f"File not found: {file_path}")
        return False, None
    
    try:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_dir = backup_dir or os.path.dirname(file_path)
        os.makedirs(backup_dir, exist_ok=True)
        
        backup_path = os.path.join(
            backup_dir,
            f"{os.path.basename(file_path)}.bak.{timestamp}"
        )
        
        shutil.copy2(file_path, backup_path)
        logger.info(f"Backup created: {backup_path}")
        return True, backup_path
    
    except Exception as e:
        logger.error(f"Backup failed for {file_path}: {str(e)}")
        return False, None

def check_root() -> bool:
    """Verify script is running as root or can use sudo"""
    if os.geteuid() == 0:
        return True
        
    # Check sudo access
    try:
        result = subprocess.run(
            ["sudo", "-n", "true"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        return result.returncode == 0
    except:
        logger.critical("This operation requires root privileges")
        return False

def validate_ip(ip: str) -> bool:
    """Validate an IP address"""
    try:
        parts = ip.split('.')
        if len(parts) != 4:
            return False
        return all(0 <= int(part) <= 255 for part in parts)
    except ValueError:
        return False

def validate_port(port: Union[str, int]) -> bool:
    """Validate a port number"""
    try:
        port = int(port)
        return 1 <= port <= 65535
    except ValueError:
        return False

def file_contains(file_path: str, pattern: str) -> bool:
    """Check if file contains a pattern"""
    try:
        with open(file_path, 'r') as f:
            return any(pattern in line for line in f)
    except IOError:
        return False

def enable_service(service_name: str) -> bool:
    """Enable and start a systemd service"""
    try:
        run_cmd(f"systemctl enable {service_name}", sudo=True, check=True)
        run_cmd(f"systemctl start {service_name}", sudo=True, check=True)
        logger.info(f"Service {service_name} enabled and started")
        return True
    except CommandError as e:
        logger.error(f"Failed to enable service {service_name}: {str(e)}")
        return False

def restart_service(service_name: str) -> bool:
    """Restart a systemd service"""
    try:
        run_cmd(f"systemctl restart {service_name}", sudo=True, check=True)
        logger.info(f"Service {service_name} restarted")
        return True
    except CommandError as e:
        logger.error(f"Failed to restart service {service_name}: {str(e)}")
        return False

def is_service_active(service_name: str) -> bool:
    """Check if a service is active"""
    success, output = run_cmd(f"systemctl is-active {service_name}", sudo=True, check=False)
    return success and output == "active"