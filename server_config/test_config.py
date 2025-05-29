#!/usr/bin/env python3
"""
Test configuration for server_app.py

Sets up a test environment with dry-run mode
"""

import os
import sys
import unittest
from server_module import dns, ssh, firewall, network, system

class TestServerConfig(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Enable dry-run mode
        os.environ['SERVER_CONFIG_DRY_RUN'] = '1'
    
    def test_system_registration(self):
        """Test system registration"""
        result = system.register_system('test_user', 'test_pass')
        self.assertTrue(result)
    
    def test_network_config(self):
        """Test network configuration"""
        result = network.configure_interfaces()
        self.assertTrue(isinstance(result, dict))
        
        result = network.set_hostname('test-host')
        self.assertTrue(result)
    
    def test_ssh_config(self):
        """Test SSH configuration"""
        result = ssh.configure_ssh(port=2222)
        self.assertTrue(result)
    
    def test_firewall_config(self):
        """Test firewall configuration"""
        result = firewall.configure_iptables(
            client_net="192.168.1.0/24",
            server_net="192.168.2.0/24"
        )
        self.assertTrue(result)
    
    def test_dns_config(self):
        """Test DNS configuration"""
        result = dns.configure_dns(
            domain="test.local",
            server_ip="192.168.1.10"
        )
        self.assertTrue(result)

if __name__ == '__main__':
    unittest.main()