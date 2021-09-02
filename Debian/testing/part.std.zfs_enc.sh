#!/bin/bash
# previous line here only to tell shellcheck what shell we're using

# `install_Debian_to_ZFS_root.sh` can source this script to set 
# these variables to determine how the install is to proceed.
# adjust to your needs This script serves two functions. First it 
# sets environment variables that control how the install is performed.
# these include ZFS settings as well as the target partitions for
# installation. Second, it prepares the test environment for testing
# in a VM or performing destructive tests on a PC. The user probably
# doesn't want to execute these when installing on their machine.

#############################  production settings
#
set -u  # treat unset vars as errors
export ETHERNET="enp0s3"
export NEW_HOSTNAME="vbx01"
export YOURUSERNAME="hbarta"
export ROOT_POOL_NAME="rpool"
export BOOT_POOL_NAME="bpool"

# LUKS encryption for 0.7 and native encryptoion for 0.8
export ZFS_CRYPT="yes"
export LUKS_CRYPT="no"
# export ENCRYPT=yes # must be set

# Select the type of installation "whole_disk|use_partitions|use_pools"
export INSTALL_TYPE="use_partitions"

# for INSTALL_TYPE="use_partitions", set the following variables
# Specify the entire path
# e.g. 'export EFI_PART=/dev/disk/by-id/ata-SATA_SSD_18120612000764-part2'

export EFI_PART=
export ROOT_PART=
export BOOT_PART=

#############################  end of production settings

#############################  testing settings and partitioning
#
# following works in Virtualbox VMs.
DRIVE_ID=$(cd /dev/disk/by-id || exit 1; find . -name "*VBOX_HARDDISK*"| sed s/^..//|sort|head -1)
export DRIVE_ID

##### build the partitions for the test and set the partition variables
# clear the drive
wipefs -a /dev/disk/by-id/"$DRIVE_ID" # useful if the drive already had ZFS pools
sgdisk --zap-all /dev/disk/by-id/"$DRIVE_ID"

# EFI partition
sgdisk -n2:1M:+512M -t2:EF00 /dev/disk/by-id/"$DRIVE_ID"
export EFI_PART=/dev/disk/by-id/"$DRIVE_ID"-part2
apt update
apt install dosfstools
mkdosfs -F 32 -s 1 -n EFI "$EFI_PART"

# boot pool partition
sgdisk -n3:0:+1024M -t3:BF01 /dev/disk/by-id/"$DRIVE_ID"
export BOOT_PART=/dev/disk/by-id/"$DRIVE_ID"-part3

# root pool partition
sgdisk -n4:0:0 -t4:BF01 /dev/disk/by-id/"$DRIVE_ID"
export ROOT_PART=/dev/disk/by-id/"$DRIVE_ID"-part4

#############################  end of testing settings and partitioning

