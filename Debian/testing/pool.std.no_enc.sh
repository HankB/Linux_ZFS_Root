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
export ZFS_CRYPT="no"
export LUKS_CRYPT="no"
# export ENCRYPT=yes # must be set

# Select the type of installation "whole_disk|use_partitions|use_pools"
export INSTALL_TYPE="use_pools"

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

##### build the partitions for the test

## First install ZFS
if [ -e /etc/apt/sources.list ] 
then
    echo deb http://deb.debian.org/debian buster contrib >> /etc/apt/sources.list
else
    if [ -d /etc/apt/sources.list.d ]
    then
        echo "deb http://deb.debian.org/debian buster main contrib" > \
            /etc/apt/sources.list.d/contrib.list
    else
        echo "can't find sources file"
        exit 1
    fi
fi

# Add backports to apt sources.

cat > /etc/apt/sources.list.d/buster-backports.list <<EOF
deb http://deb.debian.org/debian buster-backports main contrib
deb-src http://deb.debian.org/debian buster-backports main contrib
EOF

cat >  /etc/apt/preferences.d/90_zfs <<EOF
Package: libnvpair1linux libuutil1linux libzfs2linux libzpool2linux zfs-dkms \
         zfs-initramfs zfs-test zfsutils-linux zfsutils-linux-dev zfs-zed
Pin: release n=buster-backports
Pin-Priority: 990
EOF

apt update

# 1.5 Install ZFS in the Live CD environment
apt install --yes debootstrap gdisk dkms dpkg-dev linux-headers-"$(uname -r)"
apt install --yes -t buster-backports zfs-dkms
modprobe zfs

# clear the drive
wipefs -a /dev/disk/by-id/"$DRIVE_ID" # useful if the drive already had ZFS pools
sgdisk --zap-all /dev/disk/by-id/"$DRIVE_ID"

# EFI
sgdisk -n2:1M:+512M -t2:EF00 /dev/disk/by-id/"$DRIVE_ID"
export EFI_PART=/dev/disk/by-id/"$DRIVE_ID"-part2

apt install dosfstools
mkdosfs -F 32 -s 1 -n EFI "$EFI_PART"

# boot
sgdisk -n3:0:+1024M -t3:BF01 /dev/disk/by-id/"$DRIVE_ID"
export BOOT_PART=/dev/disk/by-id/"$DRIVE_ID"-part3

# root
sgdisk -n4:0:0 -t4:BF01 /dev/disk/by-id/"$DRIVE_ID"
export ROOT_PART=/dev/disk/by-id/"$DRIVE_ID"-part4

partprobe  /dev/disk/by-id/"$DRIVE_ID"
sleep 3 # avoid '$BOOT_PART': No such file or directory - Virtualbox artifact?


## Create the pools

    # 2.3 Create the boot pool
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
        -o feature@zpool_checkpoint=enabled \
        -o feature@spacemap_v2=enabled \
        -o feature@project_quota=enabled \
        -o feature@resilver_defer=enabled \
        -o feature@allocation_classes=enabled \
        -O acltype=posixacl -O canmount=off -O compression=lz4 -O devices=off \
        -O normalization=formD -O relatime=on -O xattr=sa \
        -O mountpoint=/ -R /mnt -f \
        "${BOOT_POOL_NAME}" "$BOOT_PART"

        # 2.4a Unencrypted
        zpool create -o ashift=12 \
            -O acltype=posixacl -O canmount=off -O compression=lz4 \
            -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
            -O mountpoint=/ -R /mnt -f \
            "${ROOT_POOL_NAME}" "$ROOT_PART"

#####


# for INSTALL_TYPE=use_pools, set the following variable
# Specify entire path
# e.g. 'export EFI_PART=/dev/disk/by-id/ata-SATA_SSD_18120612000764-part2'

# export EFI_PART=

# export ENCRYPT="yes|no"

# LOCAL SETTINGS - may not otherwise be useful
