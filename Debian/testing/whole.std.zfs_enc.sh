#!/bin/bash
# previous line here only to tell shellcheck what shell we're using

# `install_Debian_to_ZFS_root.sh` can source this script to set 
# these variables to determine how the install is to proceed.
# adjust to your needs

set -u  # treat unset vars as errors
export ETHERNET="enp0s3"
export NEW_HOSTNAME="vbx01"
export YOURUSERNAME="hbarta"
export ROOT_POOL_NAME="rpool"
export BOOT_POOL_NAME="bpool"

# LUKS encryption for 0.7 and native encryptoion for 0.8
export ZFS_CRYPT="yes"
export LUKS_CRYPT="no"
# export ZFS_CRYPT="no" # must be set

# Select the type of installation "whole_disk|use_partitions|use_pools"
export INSTALL_TYPE="whole_disk"

# for INSTALL_TYPE="use_partitions", set the following variables
# Specify the entire path
# e.g. 'export EFI_PART=/dev/disk/by-id/ata-SATA_SSD_18120612000764-part2'

export EFI_PART=
export ROOT_PART=
export BOOT_PART=

# for INSTALL_TYPE=whole_disk, set the following variable
# specify only the last part of the path.
# e,g `export DRIVE_ID=ata-SATA_SSD_18120612000764`

export DRIVE_ID="ata-VBOX_HARDDISK_VBfafda65f-8b22812e"

# following works in Virtualbox VMs.
DRIVE_ID=$(cd /dev/disk/by-id || exit 1; find . -name "*VBOX_HARDDISK*"| sed s/^..//|sort|head -1)
export DRIVE_ID


# for INSTALL_TYPE=use_pools, set the following variable
# Specify entire path
# e.g. 'export EFI_PART=/dev/disk/by-id/ata-SATA_SSD_18120612000764-part2'

export EFI_PART=

# export ENCRYPT="yes|no"

# LOCAL SETTINGS - may not otherwise be useful
# Use Apt-Cacher NG to reduce load on Debian repo servers
export "http_proxy=http://oak:3142"

