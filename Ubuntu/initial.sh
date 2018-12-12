#!/bin/bash
# Perform steps up to and including installing SSH server

set -u
set -e
set -x

# 1.2 Setup and update the repositories
sudo apt-add-repository universe
sudo apt update

# 1.3 Optional: Install and start the OpenSSH server in the Live CD environment
#bypass password quality check
sudo passwd ubuntu      
sudo apt install --yes openssh-server

# ssh in and run next script
