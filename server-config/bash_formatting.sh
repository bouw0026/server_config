#!/bin/bash

mkdir -p /etc/server-config
cd /etc/server-config
git clone https://github.com/bouw0026/server_config/tree/main/server-config .
Set up the required directory structure:

mkdir -p /etc/server-config/backups
mkdir -p /var/log
touch /var/log/server-config.log
chmod 755 *.sh

#Create the main configuration directory:

mkdir -p /etc/server-config
chown -R root:root /etc/server-config
chmod 750 /etc/server-config

#Create a client template directory

mkdir -p /etc/server-config/slient-templates

cd /etc/server-config
./menu.sh
