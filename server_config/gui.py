# ~/server_config/gui.py
#!/usr/bin/env python3
"""
Server Configuration GUI

A graphical interface for managing server configuration
"""

import tkinter as tk
from tkinter import ttk, messagebox
import yaml
import os
from server_config.server_module import dns, ssh, firewall, network, system

class ConfigGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Server Configuration Tool")
        self.root.geometry("800x600")
        
        # Load configuration
        self.config_file = os.path.join(os.path.dirname(__file__), 'config.yaml')
        self.load_config()
        
        # Create main notebook
        self.notebook = ttk.Notebook(root)
        self.notebook.pack(expand=True, fill='both', padx=10, pady=5)
        
        # Create tabs
        self.create_system_tab()
        self.create_network_tab()
        self.create_ssh_tab()
        self.create_firewall_tab()
        self.create_dns_tab()
        
        # Save button
        save_btn = ttk.Button(root, text="Save Configuration", command=self.save_config)
        save_btn.pack(pady=10)
        
        # Apply button
        apply_btn = ttk.Button(root, text="Apply Configuration", command=self.apply_config)
        apply_btn.pack(pady=5)

    def load_config(self):
        """Load configuration from YAML file"""
        try:
            with open(self.config_file, 'r') as f:
                self.config = yaml.safe_load(f)
        except FileNotFoundError:
            messagebox.showerror("Error", f"Configuration file not found: {self.config_file}")
            self.config = {}
        except yaml.YAMLError as e:
            messagebox.showerror("Error", f"Error parsing configuration: {str(e)}")
            self.config = {}

    def save_config(self):
        """Save configuration to YAML file"""
        try:
            # Update config from GUI
            self.update_config_from_gui()
            
            # Write to file
            with open(self.config_file, 'w') as f:
                yaml.dump(self.config, f, default_flow_style=False)
            
            messagebox.showinfo("Success", "Configuration saved successfully")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save configuration: {str(e)}")

    def create_system_tab(self):
        """Create system configuration tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="System")
        
        # Red Hat credentials
        ttk.Label(frame, text="Red Hat Subscription").grid(row=0, column=0, pady=10)
        
        ttk.Label(frame, text="Username:").grid(row=1, column=0)
        self.rh_username = ttk.Entry(frame)
        self.rh_username.insert(0, self.config.get('system', {}).get('username', ''))
        self.rh_username.grid(row=1, column=1)
        
        ttk.Label(frame, text="Password:").grid(row=2, column=0)
        self.rh_password = ttk.Entry(frame, show="*")
        self.rh_password.insert(0, self.config.get('system', {}).get('password', ''))
        self.rh_password.grid(row=2, column=1)

    def create_network_tab(self):
        """Create network configuration tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="Network")
        
        # Network settings
        fields = [
            ("Interface:", "interface"),
            ("Hostname:", "hostname"),
            ("Domain:", "domain"),
            ("Server IP:", "server_ip"),
            ("Client IP:", "client_ip"),
            ("Alias IP:", "alias_ip")
        ]
        
        self.network_entries = {}
        for i, (label, key) in enumerate(fields):
            ttk.Label(frame, text=label).grid(row=i, column=0, pady=5)
            entry = ttk.Entry(frame)
            entry.insert(0, self.config.get('network', {}).get(key, ''))
            entry.grid(row=i, column=1)
            self.network_entries[key] = entry

    def create_ssh_tab(self):
        """Create SSH configuration tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="SSH")
        
        # SSH settings
        fields = [
            ("Port:", "port"),
            ("User:", "user"),
            ("Key Path:", "key_path"),
            ("Interface:", "red_interface")
        ]
        
        self.ssh_entries = {}
        for i, (label, key) in enumerate(fields):
            ttk.Label(frame, text=label).grid(row=i, column=0, pady=5)
            entry = ttk.Entry(frame)
            entry.insert(0, self.config.get('ssh', {}).get(key, ''))
            entry.grid(row=i, column=1)
            self.ssh_entries[key] = entry

    def create_firewall_tab(self):
        """Create firewall configuration tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="Firewall")
        
        # Firewall settings
        fields = [
            ("Client Subnet:", "client_subnet"),
            ("Server Subnet:", "server_subnet")
        ]
        
        self.firewall_entries = {}
        for i, (label, key) in enumerate(fields):
            ttk.Label(frame, text=label).grid(row=i, column=0, pady=5)
            entry = ttk.Entry(frame)
            entry.insert(0, self.config.get('firewall', {}).get(key, ''))
            entry.grid(row=i, column=1)
            self.firewall_entries[key] = entry

    def create_dns_tab(self):
        """Create DNS configuration tab"""
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text="DNS")
        
        # DNS settings
        fields = [
            ("Port:", "port"),
            ("Zone Directory:", "zone_dir"),
            ("Config File:", "config_file")
        ]
        
        self.dns_entries = {}
        for i, (label, key) in enumerate(fields):
            ttk.Label(frame, text=label).grid(row=i, column=0, pady=5)
            entry = ttk.Entry(frame)
            entry.insert(0, self.config.get('dns', {}).get(key, ''))
            entry.grid(row=i, column=1)
            self.dns_entries[key] = entry

    def update_config_from_gui(self):
        """Update configuration dictionary from GUI values"""
        # System
        if 'system' not in self.config:
            self.config['system'] = {}
        self.config['system']['username'] = self.rh_username.get()
        self.config['system']['password'] = self.rh_password.get()
        
        # Network
        if 'network' not in self.config:
            self.config['network'] = {}
        for key, entry in self.network_entries.items():
            self.config['network'][key] = entry.get()
        
        # SSH
        if 'ssh' not in self.config:
            self.config['ssh'] = {}
        for key, entry in self.ssh_entries.items():
            self.config['ssh'][key] = entry.get()
        
        # Firewall
        if 'firewall' not in self.config:
            self.config['firewall'] = {}
        for key, entry in self.firewall_entries.items():
            self.config['firewall'][key] = entry.get()
        
        # DNS
        if 'dns' not in self.config:
            self.config['dns'] = {}
        for key, entry in self.dns_entries.items():
            self.config['dns'][key] = entry.get()

    def apply_config(self):
        """Apply the current configuration"""
        try:
            # Save current config first
            self.save_config()
            
            if messagebox.askyesno("Confirm", "Are you sure you want to apply this configuration?"):
                # System registration
                if self.config['system']['username'] and self.config['system']['password']:
                    system.register_system(
                        self.config['system']['username'],
                        self.config['system']['password']
                    )
                
                # Network configuration
                network.configure_interfaces(self.config['network']['interface'])
                network.set_hostname(self.config['network']['hostname'])
                
                # SSH configuration
                ssh.configure_ssh(
                    port=int(self.config['ssh']['port']),
                    user=self.config['ssh']['user']
                )
                
                # Firewall configuration
                firewall.configure_iptables(
                    client_net=self.config['firewall']['client_subnet'],
                    server_net=self.config['firewall']['server_subnet']
                )
                
                # DNS configuration
                dns.configure_dns(
                    domain=self.config['network']['domain'],
                    server_ip=self.config['network']['server_ip']
                )
                
                messagebox.showinfo("Success", "Configuration applied successfully")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to apply configuration: {str(e)}")

def main():
    root = tk.Tk()
    app = ConfigGUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()