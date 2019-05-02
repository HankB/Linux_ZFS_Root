# source this script to set these variables in the user environment
# adjust to your needs
set -u  # treat unset vars as errors
export ETHERNET=enp0s3
export NEW_HOSTNAME=vbx01
export YOURUSERNAME=hbarta
export ROOT_POOL_NAME=rpool
export BOOT_POOL_NAME=bpool
export ENCRYPT=no
# export ENCRYPT=yes # must be set

# Select the type of installation
export INSTALL_TYPE="use_partitions"

# for INSTALL_TYPE=use_partitions
##### build the partitions for the test
DRIVE_ID=ata-VBOX_HARDDISK_VB11016b68-60bc19dc
wipefs -a /dev/disk/by-id/$DRIVE_ID # useful if the drive already had ZFS pools
sgdisk --zap-all /dev/disk/by-id/$DRIVE_ID
# EFI
sgdisk -n2:1M:+512M -t2:EF00 /dev/disk/by-id/$DRIVE_ID
apt update
apt install dosfstools
mkdosfs -F 32 -s 1 -n EFI /dev/disk/by-id/${DRIVE_ID}-part2

# boot
sgdisk -n3:0:+512M -t3:BF01 /dev/disk/by-id/$DRIVE_ID

# root
sgdisk -n4:0:0 -t4:BF01 /dev/disk/by-id/$DRIVE_ID
#####

export EFI_PART=/dev/disk/by-id/${DRIVE_ID}-part2
export BOOT_PART=/dev/disk/by-id/${DRIVE_ID}-part3
export ROOT_PART=/dev/disk/by-id/${DRIVE_ID}-part4
# Specify entire path
# e.g. 'export EFI_PART=/dev/disk/by-id/ata-SATA_SSD_18120612000764-part2'

