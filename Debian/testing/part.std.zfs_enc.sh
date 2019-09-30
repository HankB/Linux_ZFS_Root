# source this script to set these variables in the user environment
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
# export ENCRYPT=yes # must be set

# Select the type of installation "whole_disk|use_partitions|use_pools"
export INSTALL_TYPE="use_partitions"

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
export DRIVE_ID=`(cd /dev/disk/by-id; ls *VBOX_HARDDISK*|head -1)`

##### build the partitions for the test
# clear the drive
wipefs -a /dev/disk/by-id/$DRIVE_ID # useful if the drive already had ZFS pools
sgdisk --zap-all /dev/disk/by-id/$DRIVE_ID

# EFI
sgdisk -n2:1M:+512M -t2:EF00 /dev/disk/by-id/$DRIVE_ID
export EFI_PART=/dev/disk/by-id/"$DRIVE_ID"-part2
apt update
apt install dosfstools
mkdosfs -F 32 -s 1 -n EFI "$EFI_PART"

# boot
sgdisk -n3:0:+1024M -t3:BF01 /dev/disk/by-id/$DRIVE_ID
export BOOT_PART=/dev/disk/by-id/"$DRIVE_ID"-part3

# root
sgdisk -n4:0:0 -t4:BF01 /dev/disk/by-id/$DRIVE_ID
export ROOT_PART=/dev/disk/by-id/$DRIVE_ID-part4
#####


# for INSTALL_TYPE=use_pools, set the following variable
# Specify entire path
# e.g. 'export EFI_PART=/dev/disk/by-id/ata-SATA_SSD_18120612000764-part2'

# export EFI_PART=

# export ENCRYPT="yes|no"

# LOCAL SETTINGS - may not otherwise be useful
# Use Apt-Cacher NG to reduce load on Debian repo servers
export http_proxy=http://oak:3142
