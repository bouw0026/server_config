# Master/Slave DNS Configuration Script - README

## Overview

This script automates the setup of a Master/Slave DNS environment with additional lab test configurations. It handles network configuration, DNS setup, SSH key exchange, firewall rules, and verification procedures for a complete lab environment.

## Key Features
 - Complete Master/Slave DNS configuration

 - IPv4 and IPv6 support

 - SSH key-based authentication setup

 - Firewall configuration (iptables)

 - Lab test environment setup

 - Comprehensive verification tools

 - Logging and backup functionality

## Configuration Variables

All configuration is done through variables at the top of the script:

## Student Information

`STUDENT_NUMBER`: Your student number (used in IP addresses)

`LAB_SECTION`: Lab section identifier

`INSTRUCTOR_NAME`: Instructor name (for documentation)

## Network Configuration

`MASTER_IP`, `SLAVE_IP`, `ALIAS_IP`: IPv4 addresses

`MASTER_IP6`, `SLAVE_IP6`, `ALIAS_IP6`: IPv6 addresses

`CLIENT_NET`, `SERVER_NET`, `LOCAL_NET`: Network ranges

## Domain Configuration

`DOMAIN`: Primary domain name

`MASTER_HOSTNAME`, SLAVE_HOSTNAME: Server hostnames

## Service Configuration

`DNS_PORT`, `SSH_PORT`: Service ports

S`SH_USER`, `SSH_KEY_TYPE`, `SSH_KEY_SIZE`: SSH configuration

## Feature Flags

`ENABLE_IPV6`: Enable/disable IPv6 support

`ENABLE_SELINUX`: Enable/disable SELinux

`ENABLE_DNSSEC`: Enable/disable DNSSEC

`FIREWALL_TYPE`: Choose between iptables/firewalld

# Command Reference
```markdown
# Main Setup Commands
| **Command**	     | **Description**                                          |
|--------------------|----------------------------------------------------------|
|`master`	         | Complete master DNS server setup                         |
|`slave`	         | Complete slave DNS server setup                          |
|`client`	         | Complete client system setup                             | 

# SSH Key Management
| **Command**	     | **Description**                                          |
|--------------------|----------------------------------------------------------|
|`master-to-slave`   | Exchange SSH keys from master to slave                   |
|`slave-to-master`	 | Exchange SSH keys from slave to master                   |
|`exchange-keys`	 | Interactive SSH key exchange setup                       |
|`finalize-ssh`      | Apply final SSH security configuration (key-only access) |

# Verification Commands
| **Command**	     | **Description**                                          |
|--------------------|----------------------------------------------------------|
|`verify [role]`	 | Comprehensive verification of all services               |
|`verify-dns`	     | DNS-specific verification                                |
|`verify-ssh`	     | SSH-specific verification                                |
|`verify-firewall`	 | Firewall-specific verification                           |

# Lab Test Commands
| **Command**	     | **Description**                                          |
|--------------------|----------------------------------------------------------|
|`lab-test-setup`	 | Setup for specific lab test requirements                 |
|`nc-setup [port]`	 | Setup netcat service for testing                         |

# Options
| **Option**	     | **Description**                                          |
|--------------------|----------------------------------------------------------|
|`--dry-run`	     | Simulate changes without executing                       |
|`--debug`	         | Enable debug output                                      |
|`--validate`	     | Validate configuration only                              |
|`--help`       	 | Show help message                                        |
```

## Lab Variations Setup

The script supports these lab test scenarios (configured in LAB_VARIATIONS):

## 1. master-slave-basic

**Description**:  Basic master/slave DNS setup

**Requirements**:

    - Master DNS server with zone files

    - Slave DNS server receiving zone transfers

    - Basic connectivity between servers

## Setup Command:

```bash
./maslave6.3.sh master   # On master server
./maslave6.3.sh slave    # On slave server
```

## 2. master-slave-client

**Description**: Master/slave with client

**Requirements**:

    - All basic master-slave setup

    - Additional client system

    - Client uses both DNS servers

    - Testing from client perspective

## Setup Command:

```bash
./maslave6.3.sh master   # On master server
./maslave6.3.sh slave    # On slave server
./maslave6.3.sh client   # On client system
```

## 3. ssh-multiuser

**Description**: SSH with multiple user access

**Requirements**:

    - Multiple user accounts (lab, foo, cst8246)

    - Different SSH access patterns

    - Key-based authentication testing

## Setup Command:

```bash
./maslave6.3.sh lab-test-setup  # On all systems
./maslave6.3.sh master-to-slave # Key exchange
./maslave6.3.sh slave-to-master # Key exchange
```

## 4. firewall-nc-restricted

**Description**: Netcat with network restrictions

**Requirements**:

    - NC services on specific ports

    - Firewall rules restricting access

    - Different rules for master/slave

## Setup Command:

```bash
./maslave6.3.sh nc-setup 49876  # On master (port 49876)
./maslave6.3.sh nc-setup 55765  # On slave (port 55765)
```
DNS with forward and reverse zones
## 5. dns-forward-reverse

**Description**: DNS with forward and reverse zones

**Requirements**:

    - Complete forward and reverse zones

    - Both IPv4 and IPv6 records

    - Zone transfer verification

## Setup Command:

```bash
./maslave6.3.sh master   # On master (creates zones)
./maslave6.3.sh slave    # On slave (receives zones)
```

# Detailed Functionality

## Network Configuration

    - Sets static IP addresses for all interfaces

    - Configures alias IP addresses

    - Sets up proper routing

    - Updates /etc/hosts file

    - Configures IPv6 if enabled

## DNS Configuration

## Master:
    
    - Installs and configures BIND

    - Creates forward and reverse zones

    - Sets up zone transfers to slave

    - Configures logging if enabled

## Slave:

    - Installs and configures BIND

    - Sets up as slave for all zones

    - Configures proper permissions

    - Sets up resolv.conf to use master

## SSH Configuration

    - Installs OpenSSH server and client

    - Configures initial SSH access (password + key)

    - Sets up SSH key exchange

    - Finalizes to key-only access

    - Configures proper permissions

## Firewall Configuration

    - Configures iptables rules

    - Restricts access based on role

    - Allows DNS and SSH traffic

    - Implements lab-specific port restrictions

## Verification Tools

    - Comprehensive service checks
    
    - DNS record validation

    - Zone transfer testing

    - Connectivity tests

    - Firewall rule verification

# Usage Examples

## Basic Master/Slave Setup:

```bash
# On master server:
./maslave6.3.sh master

# On slave server:
./maslave6.3.sh slave

# Verify setup:
./maslave6.3.sh verify master
./maslave6.3.sh verify slave
```

## SSH Key Exchange:

```bash
# From master to slave:
./maslave6.3.sh master-to-slave

# From slave to master:
./maslave6.3.sh slave-to-master

# Finalize SSH config:
./maslave6.3.sh finalize-ssh master
./maslave6.3.sh finalize-ssh slave
```

## Lab Test Setup:

```bash
# Setup firewall-nc-restricted variation:
./maslave6.3.sh nc-setup 49876 master
./maslave6.3.sh nc-setup 55765 slave

# Setup ssh-multiuser variation:
./maslave6.3.sh lab-test-setup
```

# Notes

 1. Run as root for full functionality

 2. Review configuration variables before execution

 3. Check logs in ~/.lab-config/lab-config.log

 4. Backups are stored in ~/.lab-config/backups/

 5. Use --dry-run to test before actual execution

*This script provides a complete environment for DNS lab testing with multiple configuration options to match various testing scenarios.*