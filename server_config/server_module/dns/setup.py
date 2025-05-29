#!/usr/bin/env python3
"""
DNS Server Configuration Module

Handles:
- BIND installation
- named.conf configuration
- Zone file creation
- DNS testing
"""

from ..utils import run_cmd, backup_file, check_root
from ..config import DEFAULT_NETWORK
from datetime import datetime
from typing import Tuple, Optional, List

class DNSSetup:
    def __init__(self, domain: str = None, server_ip: str = None):
        self.domain = domain or DEFAULT_NETWORK.domain
        self.server_ip = server_ip or DEFAULT_NETWORK.server_ip
        self.hostname = DEFAULT_NETWORK.hostname
        self.fqdn = DEFAULT_NETWORK.fqdn
        self.dns_port = 53
        self.allowed_networks = ["172.16.30.0/24", "172.16.31.0/24"]
        self.interfaces = ["127.0.0.1", self.server_ip, "172.16.32.25"]

    def install_packages(self) -> bool:
        """Install BIND and required utilities"""
        print("\n=== Installing BIND packages ===")
        success, output = run_cmd("dnf install -y bind bind-utils", sudo=True)
        if not success:
            raise Exception(f"Failed to install packages: {output}")
        print("BIND packages installed successfully")
        return True

    def configure_named_conf(self) -> bool:
        """Configure the main named.conf file"""
        print("\n=== Configuring /etc/named.conf ===")
        
        # Backup existing config
        success, backup_path = backup_file("/etc/named.conf")
        if not success:
            raise Exception("Failed to backup named.conf")
        print(f"Created backup at {backup_path}")

        config = f"""
options {{
    listen-on port {self.dns_port} {{ {"; ".join(self.interfaces)}; }};
    listen-on-v6 port {self.dns_port} {{ none; }};
    directory       "/var/named";
    dump-file       "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query     {{ localhost; {'; '.join(self.allowed_networks)}; }};
    recursion yes;
    forwarders {{ 8.8.8.8; 8.8.4.4; }};

    dnssec-enable yes;
    dnssec-validation yes;

    /* Path to ISC DLV key */
    bindkeys-file "/etc/named.iscdlv.key";

    managed-keys-directory "/var/named/dynamic";
}};

logging {{
    channel default_debug {{
        file "data/named.run";
        severity dynamic;
    }};
}};

zone "." IN {{
    type hint;
    file "named.ca";
}};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

zone "{self.domain}" IN {{
    type master;
    file "/var/named/{self.domain}.zone";
    allow-update {{ none; }};
}};

zone "{'.'.join(reversed(self.server_ip.split('.')[0:3]))}.in-addr.arpa" IN {{
    type master;
    file "/var/named/{self.domain}.rev";
    allow-update {{ none; }};
}};
"""

        # Write new configuration
        with open("/tmp/named.conf.tmp", "w") as f:
            f.write(config)

        # Move to final location
        run_cmd("mv /tmp/named.conf.tmp /etc/named.conf", sudo=True)
        run_cmd("chown root:named /etc/named.conf", sudo=True)
        run_cmd("chmod 640 /etc/named.conf", sudo=True)
        print("named.conf configured successfully")
        return True

    def create_zone_files(self) -> bool:
        """Create forward and reverse zone files"""
        print("\n=== Creating zone files ===")
        
        # Forward zone
        forward_zone = f"""
$TTL 86400
@   IN  SOA     {self.fqdn}. admin.{self.domain}. (
                    {datetime.now().strftime('%Y%m%d01')} ; Serial
                    3600       ; Refresh
                    1800       ; Retry
                    604800     ; Expire
                    86400      ; Minimum TTL
)
@       IN  NS      {self.fqdn}.
{self.hostname}     IN  A       {self.server_ip}
"""

        # Reverse zone
        reverse_zone = f"""
$TTL 86400
@   IN  SOA     {self.fqdn}. admin.{self.domain}. (
                    {datetime.now().strftime('%Y%m%d01')} ; Serial
                    3600       ; Refresh
                    1800       ; Retry
                    604800     ; Expire
                    86400      ; Minimum TTL
)
@       IN  NS      {self.fqdn}.
{'.'.join(reversed(self.server_ip.split('.')[-1]))}      IN  PTR     {self.fqdn}.
"""

        # Write files
        for content, filename in [(forward_zone, f"{self.domain}.zone"), 
                                 (reverse_zone, f"{self.domain}.rev")]:
            with open(f"/tmp/{filename}.tmp", "w") as f:
                f.write(content)
            
            run_cmd(f"mv /tmp/{filename}.tmp /var/named/{filename}", sudo=True)
            run_cmd(f"chown root:named /var/named/{filename}", sudo=True)
            run_cmd(f"chmod 640 /var/named/{filename}", sudo=True)
        
        print("Zone files created successfully")
        return True

    def verify_configuration(self) -> bool:
        """Verify the DNS configuration"""
        print("\n=== Verifying configuration ===")
        
        checks = [
            ("named.conf syntax", "named-checkconf"),
            (f"Forward zone {self.domain}", f"named-checkzone {self.domain} /var/named/{self.domain}.zone"),
            (f"Reverse zone", f"named-checkzone {'.'.join(reversed(self.server_ip.split('.')[0:3]))}.in-addr.arpa /var/named/{self.domain}.rev")
        ]
        
        for desc, cmd in checks:
            success, output = run_cmd(cmd, sudo=True)
            if not success:
                raise Exception(f"Error in {desc}: {output}")
            print(f"{desc} OK")
        
        return True

    def start_services(self) -> bool:
        """Start and enable the named service"""
        print("\n=== Starting services ===")
        run_cmd("systemctl enable --now named", sudo=True)
        run_cmd("systemctl restart named", sudo=True)
        print("DNS service started and enabled")
        return True

    def configure(self) -> bool:
        """Run complete DNS configuration"""
        check_root()
        self.install_packages()
        self.configure_named_conf()
        self.create_zone_files()
        self.verify_configuration()
        self.start_services()
        return True

# Module-level functions for easier import
def configure_dns(domain: str = None, server_ip: str = None) -> bool:
    """Configure DNS server with optional overrides"""
    return DNSSetup(domain, server_ip).configure()

def test_dns(server_ip: str = None) -> bool:
    """Test DNS configuration"""
    server_ip = server_ip or DEFAULT_NETWORK.server_ip
    tests = [
        ("Caching DNS", f"dig google.com @{server_ip}"),
        (f"Authoritative lookup", f"dig {DEFAULT_NETWORK.fqdn} @{server_ip}"),
        ("Reverse lookup", f"dig -x {server_ip} @{server_ip}")
    ]
    
    for desc, cmd in tests:
        print(f"\n{desc}:")
        run_cmd(cmd, capture_output=False)
    
    return True