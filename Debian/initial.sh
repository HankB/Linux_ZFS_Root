#!/bin/bash
# Perform steps up to and including installing SSH server

set -u
set -e
set -x

# 1.2 Optional: Install and start the OpenSSH server in the Live CD environment
sudo apt update
sudo apt install --yes openssh-server
sudo sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/g" \
      /etc/ssh/sshd_config
sudo service ssh restart

# 1.3 Become root 
sudo -i

# 1.4 Add contrib archive area
echo "deb http://ftp.debian.org/debian stretch main contrib" > /etc/apt/sources.list
apt update

echo "ssh in and run install_Debian_to_ZFS_root.sh

