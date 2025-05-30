#!/usr/bin/env python3
"""
Basic functionality tests for server configuration module
"""

import unittest
import os
import sys
from server_module import dns, ssh, firewall, network, system
from server_module.utils import run_cmd

class TestBasicFunctionality(unittest.TestCase):
    def setUp(self):
        # Enable test mode
        os.environ['SERVER_CONFIG_DRY_RUN'] = '1'

    def test_utils(self):
        """Test utility functions"""
        success, output = run_cmd("echo 'test'")
        self.assertTrue(success)
        self.assertEqual(output.strip(), 'test')

    def test_network_validation(self):
        """Test network configuration validation"""
        from server_module.utils import validate_ip, validate_port
        
        # Test IP validation
        self.assertTrue(validate_ip("192.168.1.1"))
        self.assertFalse(validate_ip("256.256.256.256"))
        
        # Test port validation
        self.assertTrue(validate_port(22))
        self.assertFalse(validate_port(70000))

    def test_config_loading(self):
        """Test configuration loading"""
        from server_module.config import DEFAULT_NETWORK, DEFAULT_SSH
        
        self.assertIsNotNone(DEFAULT_NETWORK.interface)
        self.assertIsNotNone(DEFAULT_SSH.port)

if __name__ == '__main__':
    unittest.main()