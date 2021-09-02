#!/bin/bash
# previous line here only to tell shellcheck what shell we're using

# `install_Debian_to_ZFS_root.sh` can source this script to set 
# these variables to determine how the install is to proceed.
# adjust to your needs.

# The variables set here will work in the Virtualbox test environment.

set -u  # treat unset vars as errors
export ETHERNET="enp0s3"
export NEW_HOSTNAME="vbx01"
export YOURUSERNAME="hbarta"
export ROOT_POOL_NAME="rpool"
export BOOT_POOL_NAME="bpool"

# LUKS encryption for 0.7 and native encryption for 0.8
export ZFS_CRYPT="no"
export LUKS_CRYPT="no"

# Select the type of installation "whole_disk|use_partitions|use_pools"
export INSTALL_TYPE="whole_disk"

# for INSTALL_TYPE=whole_disk, set the following variable
# specify only the last part of the path.
# e,g `export DRIVE_ID=ata-SATA_SSD_18120612000764`

# following works in Virtualbox VMs. for other environments you will need to determine the correct 
# value for DRIVE_ID
DRIVE_ID=$(cd /dev/disk/by-id || exit 1; find . -name "*VBOX_HARDDISK*"| sed s/^..//|sort|head -1)
export DRIVE_ID

# Uncomment this to install using BIOS/MBR boot. Default if unset is EFI
## BOOT_TYPE="BIOS"