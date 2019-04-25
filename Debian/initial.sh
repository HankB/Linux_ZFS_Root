#!/bin/bash
# Perform steps up to and including installing SSH server

set -u
set -e
set -x

# 1.2 Optional: Install and start the OpenSSH server in the Live CD environment
sudo apt update
sudo apt install --yes openssh-server
sudo service ssh restart

# 1.3 Become root 
## sudo -i

echo; echo "ssh in and run install_Debian_to_ZFS_root.sh"

