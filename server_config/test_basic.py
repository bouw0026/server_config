#!/usr/bin/env python3
"""
Basic functionality tests for server configuration module
"""

import unittest
import os
import sys
from server_module.utils import run_cmd, validate_ip, validate_port

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
        # Test IP validation
        self.assertTrue(validate_ip("192.168.1.1"))
        self.assertFalse(validate_ip("256.256.256.256"))
        
        # Test port validation
        self.assertTrue(validate_port(22))
        self.assertFalse(validate_port(70000))

    def test_file_operations(self):
        """Test file operations"""
        test_file = "test_file.txt"
        
        # Create test file
        with open(test_file, "w") as f:
            f.write("test content")
        
        # Test file exists
        self.assertTrue(os.path.exists(test_file))
        
        # Clean up
        os.remove(test_file)

if __name__ == '__main__':
    unittest.main()