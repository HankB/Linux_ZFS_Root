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
export INSTALL_TYPE="use_pools"

# for INSTALL_TYPE=use_partitions
##### build the partitions for the test

if [ -e /etc/apt/sources.list ] 
then
    echo deb http://deb.debian.org/debian buster contrib >> /etc/apt/sources.list
else
    if [ -d /etc/apt/sources.list.d ]
    then
        echo "deb http://deb.debian.org/debian buster contrib" >> /etc/apt/sources.list.d/contrib.list
/backports.list
    else
        echo "can't find sources file"
        exit 1
    fi
fi
apt update

# 1.5 Install ZFS in the Live CD environment
apt install --yes debootstrap gdisk dkms dpkg-dev linux-headers-$(uname -r)
apt install --yes zfs-dkms
modprobe zfs


DRIVE_ID=ata-VBOX_HARDDISK_VBfafda65f-8b22812e
wipefs -a /dev/disk/by-id/$DRIVE_ID # useful if the drive already had ZFS pools
sgdisk --zap-all /dev/disk/by-id/$DRIVE_ID
# EFI
sgdisk -n2:1M:+512M -t2:EF00 /dev/disk/by-id/$DRIVE_ID
# boot
sgdisk -n3:0:+512M -t3:BF01 /dev/disk/by-id/$DRIVE_ID
# root
sgdisk -n4:0:0 -t4:BF01 /dev/disk/by-id/$DRIVE_ID
partprobe  /dev/disk/by-id/$DRIVE_ID

# efi
apt update
apt install dosfstools
mkdosfs -F 32 -s 1 -n EFI /dev/disk/by-id/${DRIVE_ID}-part2

# boot
export BOOT_PART=/dev/disk/by-id/${DRIVE_ID}-part3
zpool create -o ashift=12 -d \
	-o feature@async_destroy=enabled \
	-o feature@bookmarks=enabled \
	-o feature@embedded_data=enabled \
	-o feature@empty_bpobj=enabled \
	-o feature@enabled_txg=enabled \
	-o feature@extensible_dataset=enabled \
	-o feature@filesystem_limits=enabled \
	-o feature@hole_birth=enabled \
	-o feature@large_blocks=enabled \
	-o feature@lz4_compress=enabled \
	-o feature@spacemap_histogram=enabled \
	-o feature@userobj_accounting=enabled \
	-O acltype=posixacl -O canmount=off -O compression=lz4 -O devices=off \
	-O normalization=formD -O relatime=on -O xattr=sa \
	-O mountpoint=/ -R /mnt -f \
    ${BOOT_POOL_NAME} $BOOT_PART

# root
export ROOT_PART=/dev/disk/by-id/${DRIVE_ID}-part4
zpool create -o ashift=12 \
	-O acltype=posixacl -O canmount=off -O compression=lz4 \
	-O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
	-O mountpoint=/ -R /mnt -f \
    ${ROOT_POOL_NAME} $ROOT_PART

#####




# for INSTALL_TYPE=use_pools
export EFI_PART=/dev/disk/by-id/${DRIVE_ID}-part2
# Specify entire path
# e.g. 'export EFI_PART=/dev/disk/by-id/ata-SATA_SSD_18120612000764-part2'

