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
export INSTALL_TYPE="whole_disk"

# for INSTALL_TYPE=use_partitions

export EFI_PART=
export ROOT_PART=
export BOOT_PART=
# Specify entire path
# e.g. 'export EFI_PART=/dev/disk/by-id/ata-SATA_SSD_18120612000764-part2'

# for INSTALL_TYPE=whole_disk

export DRIVE_ID=ata-VBOX_HARDDISK_VBcd1d4854-e6190a19
# specify only the last part of the path.
# e,g `export DRIVE_ID=ata-SATA_SSD_18120612000764`

# for INSTALL_TYPE=use_pools
export EFI_PART=
# Specify entire path
# e.g. 'export EFI_PART=/dev/disk/by-id/ata-SATA_SSD_18120612000764-part2'

# export ENCRYPT="yes|no"
