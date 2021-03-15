#!/bin/bash

# 1.3 Become root:
# sudo -i
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi
set -euo pipefail
# set -e            # exit on error
# set -u            # treat unset variables as errors
# set -o pipefail   # check exit status of all commands in pipeline
set -x            # expand commands - for debugging (temporary)

if [ "$#"  == 0 ]; then
    echo 'using default ENV vars (env.sh)'
    # shellcheck disable=SC1091
    # user required to copy to same dir
    source env.sh
else
    echo Getting ENV vars from "$1"
    # shellcheck source=/dev/null
    source "$1"
fi

# Verify consistency of ENV vars

# Make sure $ZFS_CRYPT is set to something, default to 'no'
if [ -z ${ZFS_CRYPT+x} ]
then
    export ZFS_CRYPT="no"
fi

if [ -z ${LUKS_CRYPT+x} ]
then
    export LUKS_CRYPT="no"
fi

# 1.4 disable automounting

gsettings set org.gnome.desktop.media-handling automount false

# 1.2 Setup and update the repositories: (sorry, order changed in instructions)

echo deb http://deb.debian.org/debian buster main contrib >> /etc/apt/sources.list
echo deb http://deb.debian.org/debian buster-backports main contrib >> /etc/apt/sources.list

apt update

# 1.6 Install ZFS in the Live CD environment
apt install --yes debootstrap gdisk dkms dpkg-dev linux-headers-"$(uname -r)"
apt install --yes -t buster-backports --no-install-recommends zfs-dkms
modprobe zfs
apt install --yes -t buster-backports zfsutils-linux

# 3 Disk Partitioning

if [ "$INSTALL_TYPE" == "whole_disk" ];then
    # 2 If you are re-using a disk, clear it as necessary
    # If the disk was previously used in an MD array, zero the superblock:
    apt install --yes mdadm
    mdadm --zero-superblock --force /dev/disk/by-id/"$DRIVE_ID"

    wipefs -a /dev/disk/by-id/"$DRIVE_ID"   # useful if the drive already had ZFS pools
    sgdisk --zap-all /dev/disk/by-id/"$DRIVE_ID"

    # 3 Partition your disk
    # Run this for UEFI booting (for use now or in the future):
    sgdisk     -n2:1M:+512M -t2:EF00 /dev/disk/by-id/"$DRIVE_ID"
    export EFI_PART=/dev/disk/by-id/"$DRIVE_ID"-part2

    # Run this for the boot pool:
    sgdisk     -n3:0:+1G       -t3:BF01 /dev/disk/by-id/"$DRIVE_ID"
    export BOOT_PART=/dev/disk/by-id/"$DRIVE_ID"-part3

    # 2.2 main pool 
    if [ "$LUKS_CRYPT" == "no" ]; then
        sgdisk     -n4:0:0      -t4:BF00 /dev/disk/by-id/"$DRIVE_ID"
    else
        sgdisk     -n4:0:0      -t4:8309 /dev/disk/by-id/"$DRIVE_ID"
    fi

    export ROOT_PART=/dev/disk/by-id/${DRIVE_ID}-part4
    partprobe  /dev/disk/by-id/"$DRIVE_ID"
    sleep 3 # avoid '$BOOT_PART': No such file or directory - Virtualbox artifact?
elif [ "$INSTALL_TYPE" == "use_partitions" ];then
    echo "using $ROOT_PART for root partition"
    echo "using $BOOT_PART for boot partition"
    wipefs -a "$ROOT_PART"  # useful if the partition already had ZFS pools
    wipefs -a "$BOOT_PART"  # useful if the partition already had ZFS pools
    echo "using $EFI_PART for EFI partition"
elif [ "$INSTALL_TYPE" == "use_pools" ];then
    echo "using $ROOT_POOL_NAME for root pool"
    echo "using $BOOT_POOL_NAME for boot pool"
    echo "using $EFI_PART for EFI partition"

else
    echo set INSTALL_TYPE to \"whole_disk\" or \"use_partitions\" or \"use_pools\"
    exit 1
fi

if [ "$INSTALL_TYPE" != "use_pools" ];then 
    # 4 Create the boot pool
    zpool create \
        -o cachefile=/etc/zfs/zpool.cache \
        -o ashift=12 -d \
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
        -o feature@zpool_checkpoint=enabled \
        -o feature@spacemap_v2=enabled \
        -o feature@project_quota=enabled \
        -o feature@resilver_defer=enabled \
        -o feature@allocation_classes=enabled \
        -O acltype=posixacl -O canmount=off -O compression=lz4 -O devices=off \
        -O normalization=formD -O relatime=on -O xattr=sa \
        -O mountpoint=/boot -R /mnt -f \
        "${BOOT_POOL_NAME}" "$BOOT_PART"

    # 5 Create the root pool
    if [ "$LUKS_CRYPT" == yes ]; then
        # LUKS encryption
        apt install --yes cryptsetup
        cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha256 "$ROOT_PART"
        cryptsetup luksOpen "$ROOT_PART" luks1
        zpool create \
            -o ashift=12 \
            -O acltype=posixacl -O canmount=off -O compression=lz4 \
            -O dnodesize=auto -O normalization=formD -O relatime=on \
            -O xattr=sa -O mountpoint=/ -R /mnt \
            "${ROOT_POOL_NAME}" /dev/mapper/luks1
    elif [ "$ZFS_CRYPT" == "yes" ]; then
        # ZFS native encryption
        zpool create -o ashift=12 \
            -O acltype=posixacl -O canmount=off -O compression=lz4 \
            -O dnodesize=auto -O normalization=formD -O relatime=on \
            -O xattr=sa -O encryption=aes-256-gcm -O keylocation=prompt -O keyformat=passphrase \
            -O mountpoint=/ -R /mnt -f \
            "${ROOT_POOL_NAME}" "$ROOT_PART"
    else
        # Unencrypted
        zpool create \
            -o ashift=12 \
            -O acltype=posixacl -O canmount=off -O compression=lz4 \
            -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
            -O mountpoint=/ -R /mnt -f \
            "${ROOT_POOL_NAME}" "$ROOT_PART"
    fi
fi

# 3.1 Create filesystem datasets to act as containers
zfs create -o canmount=off -o mountpoint=none "${ROOT_POOL_NAME}"/ROOT
zfs create -o canmount=off -o mountpoint=none "${BOOT_POOL_NAME}"/BOOT

# 3.2 Create a filesystem datasets for the root and boot filesystems
zfs create -o canmount=noauto -o mountpoint=/ "${ROOT_POOL_NAME}"/ROOT/debian
zfs mount "${ROOT_POOL_NAME}"/ROOT/debian

zfs create -o canmount=noauto -o mountpoint=/boot "${BOOT_POOL_NAME}"/BOOT/debian
zfs mount "${BOOT_POOL_NAME}"/BOOT/debian

# 3.3 Create datasets
zfs create                                            "${ROOT_POOL_NAME}"/home
zfs create -o mountpoint=/root                        "${ROOT_POOL_NAME}"/home/root
chmod 700 /mnt/root
zfs create -o canmount=off                            "${ROOT_POOL_NAME}"/var
zfs create -o canmount=off                            "${ROOT_POOL_NAME}"/var/lib
zfs create                                            "${ROOT_POOL_NAME}"/var/log
zfs create                                            "${ROOT_POOL_NAME}"/var/spool
# If you wish to exclude these from snapshots:
zfs create -o com.sun:auto-snapshot=false             "${ROOT_POOL_NAME}"/var/cache
zfs create -o com.sun:auto-snapshot=false             "${ROOT_POOL_NAME}"/var/tmp
chmod 1777 /mnt/var/tmp

# If you use /opt on this system:
zfs create                                            "${ROOT_POOL_NAME}"/opt

# If you use /srv on this system:
zfs create                                            "${ROOT_POOL_NAME}"/srv

# If you use /usr/local on this system:
zfs create -o canmount=off                            "${ROOT_POOL_NAME}"/usr
zfs create                                            "${ROOT_POOL_NAME}"/usr/local

# If this system will have games installed:
zfs create                                            "${ROOT_POOL_NAME}"/var/games

# If this system will store local email in /var/mail:
zfs create                                            "${ROOT_POOL_NAME}"/var/mail

# If this system will use Snap packages:
zfs create                                            "${ROOT_POOL_NAME}"/var/snap

# If you use /var/www on this system:
zfs create                                            "${ROOT_POOL_NAME}"/var/www

# If this system will use GNOME:
zfs create                                            "${ROOT_POOL_NAME}"/var/lib/AccountsService

# If this system will use Docker (which manages its own datasets & snapshots):
zfs create -o com.sun:auto-snapshot=false             "${ROOT_POOL_NAME}"/var/lib/docker

# If this system will use NFS (locking):
zfs create -o com.sun:auto-snapshot=false             "${ROOT_POOL_NAME}"/var/lib/nfs

# Mount a tmpfs at /run:
mkdir /mnt/run
mount -t tmpfs tmpfs /mnt/run
mkdir /mnt/run/lock

# A tmpfs is recommended later, but if you want a separate dataset for /tmp:
# zfs create -o com.sun:auto-snapshot=false  rpool/tmp
# chmod 1777 /mnt/tmp

# 3.4 Install the minimal system
debootstrap buster /mnt http://deb.debian.org/debian

# Copy in zpool.cache
mkdir /mnt/etc/zfs
cp /etc/zfs/zpool.cache /mnt/etc/zfs/

# 4.1 Configure the hostname (change HOSTNAME to the desired hostname).
echo "$NEW_HOSTNAME" > /mnt/etc/hostname
echo "127.0.1.1       $NEW_HOSTNAME" >> /mnt/etc/hosts
# Add a line:
# 127.0.1.1       HOSTNAME
# or if the system has a real name in DNS:
# 127.0.1.1       FQDN HOSTNAME

# 4.2 Configure the network interface:
# Find the interface name:
# ip addr show
cat >/mnt/etc/network/interfaces.d/"${ETHERNET}" <<EOF
auto ${ETHERNET}
iface ${ETHERNET} inet dhcp
EOF

# 4.3  Configure the package sources:
# Add `contrib` archive area:
sed -i "s/^/# /" /mnt/etc/apt/sources.list
cat <<EOF >> /mnt/etc/apt/sources.list
deb http://deb.debian.org/debian buster main contrib
deb-src http://deb.debian.org/debian buster main contrib

deb http://security.debian.org/debian-security buster/updates main contrib
deb-src http://security.debian.org/debian-security buster/updates main contrib
EOF

# Add backports to apt sources

cat > /mnt/etc/apt/sources.list.d/buster-backports.list <<EOF
deb http://deb.debian.org/debian buster-backports main contrib
deb-src http://deb.debian.org/debian buster-backports main contrib
EOF

cat >  /mnt/etc/apt/preferences.d/90_zfs <<EOF
Package: libnvpair1linux libuutil1linux libzfs2linux libzfs2linux-dev \
         libzpool2linux python3-pyzfs pyzfs-doc spl spl-dkms zfs-dkms \
         zfs-dracut zfs-initramfs zfs-test zfsutils-linux zfsutils-linux-dev zfs-zed         
Pin: release n=buster-backports
Pin-Priority: 990
EOF


# 4.4  Bind the virtual filesystems from the LiveCD environment to the new system
# and `chroot` into it:

mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys
mount -t tmpfs tmpfs /mnt/run

#chroot /mnt /bin/bash --login

# Build a script to run in the chroot enbvironment
cat <<END_OF_CHROOT >/mnt/usr/local/sbin/chroot_commands.sh
#!/bin/bash

set -euo pipefail
# set -e            # exit on error
# set -u            # treat unset variables as errors
# set -o pipefail   # check exit status of all commands in pipeline
set -x            # expand commands - for debugging

# 4.5 Configure a basic system environment
ln -s /proc/self/mounts /etc/mtab
apt update
apt install --yes console-setup locales
dpkg-reconfigure locales tzdata keyboard-configuration console-setup

# 4.6 Install ZFS in the chroot environment for the new system
apt install --yes dpkg-dev linux-headers-amd64 linux-image-amd64
apt install --yes zfs-initramfs
echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf

# 4.7 For LUKS installs only, setup crypttab:
if [ "\$LUKS_CRYPT" == "yes" ]; then
    apt install --yes cryptsetup
    echo luks1 UUID=\$(blkid -s UUID -o value \
        "\$ROOT_PART") none \
        luks,discard,initramfs > /etc/crypttab
fi


# 4.8 Install GRUB
# 4.7b Install GRUB for UEFI booting
if [ "\$INSTALL_TYPE" == "whole_disk" ];then
    apt install dosfstools
    mkdosfs -F 32 -s 1 -n EFI \${EFI_PART}
fi
mkdir /boot/efi
echo \${EFI_PART} \
      /boot/efi vfat nofail,x-systemd.device-timeout=1 0 1 >> /etc/fstab
mount /boot/efi
apt install --yes grub-efi-amd64 shim-signed

# 4.9 Set a root password
echo "set a root password"
set +e
while ! passwd 
do
	echo try again
done
set -e

# 4.9 Enable importing bpool
cat <<EOF >/etc/systemd/system/zfs-import-"\${BOOT_POOL_NAME}".service
[Unit]
DefaultDependencies=no
Before=zfs-import-scan.service
Before=zfs-import-cache.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/zpool import -N -o cachefile=none "\${BOOT_POOL_NAME}"
# Work-around to prese5rve zpool cache
ExecStartPre=~/bin/mv /etc/zfs/zpool.cache /etc/zfs/preboot_zpool.cache
ExecStartPost=~/bin/mv /etc/zfs/preboot_zpool.cache /etc/zfs/zpool.cache

[Install]
WantedBy=zfs-import.target
EOF

systemctl enable zfs-import-"\${BOOT_POOL_NAME}".service

# 4.10 Optional (but recommended): Mount a tmpfs to /tmp
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

# 4.11 Optional (but kindly requested): Install popcon
apt install --yes popularity-contest

# 5.1 Verify that the ZFS root filesystem is recognized
if ! [ \`grub-probe /boot\` == "zfs" ];then
    echo "grub-probe != zfs"
    exit 1
fi

# 5.2 Refresh the initrd files
update-initramfs -u -k all

# 5.3 Workaround GRUB's missing zpool-features support:
sed -i "s|^GRUB_CMDLINE_LINUX=\"|GRUB_CMDLINE_LINUX=\"root=ZFS=\${ROOT_POOL_NAME}/ROOT/debian |" \
        /etc/default/grub

# 5.4 Optional (but highly recommended): Make debugging GRUB easier
sed -i "s/quiet//" /etc/default/grub
sed -i "s/#GRUB_TERMINAL/GRUB_TERMINAL/" /etc/default/grub

# 5.5 Update the boot configuration
update-grub

# 5.6 Install the boot loader
# 5.6b For UEFI booting, install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
      --bootloader-id=debian --recheck --no-floppy

# 5.7 Verify that the ZFS module is installed
ls /boot/grub/*/zfs.mod

# 5.8 Fix filesystem mount ordering

# For UEFI booting, unmount /boot/efi first:
umount /boot/efi

# Everything else applies to both BIOS and UEFI booting:


zfs set mountpoint=legacy "\${BOOT_POOL_NAME}"/BOOT/debian
echo "\${BOOT_POOL_NAME}"/BOOT/debian /boot zfs \
    nodev,relatime,x-systemd.requires=zfs-import-${BOOT_POOL_NAME}.service 0 0 >> /etc/fstab

mkdir /etc/zfs/zfs-list.cache
touch /etc/zfs/zfs-list.cache/"\${ROOT_POOL_NAME}"
touch /etc/zfs/zfs-list.cache/"\${BOOT_POOL_NAME}"
# ln -s /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d

## This next section has been a little problematic. For now, just do a 'best effort'
## Getting `zed` to populate the cache files. Start it, delay 30 seconds and kill it.
zed -F &
ZED_PID=\$!
echo delay 30 seconds
sleep 30
## 
## 
## # loop while zed does its thing root pool first
## while ! ( [ -f /etc/zfs/zfs-list.cache/"\${ROOT_POOL_NAME}" ] && \
##           [ -s /etc/zfs/zfs-list.cache/"\${ROOT_POOL_NAME}" ] )
## do
##     sleep 3
##     # If it is empty, force a cache update and check again:
##     zfs set canmount=noauto "\${ROOT_POOL_NAME}"/ROOT/debian
## done
## 
## # now boot pool
## while ! ( [ -f /etc/zfs/zfs-list.cache/"\${BOOT_POOL_NAME}" ] && \
##           [ -s /etc/zfs/zfs-list.cache/"\${BOOT_POOL_NAME}" ] )
## do
##     sleep 3
##     # If it is empty, force a cache update and check again:
##     zfs set canmount=on "\${BOOT_POOL_NAME}"/BOOT/debian
## done
## 
## # delay one more time to avoid apparent race condition
## sleep 3
kill \$ZED_PID
ls -l  /etc/zfs/zfs-list.cache/"\${BOOT_POOL_NAME}" /etc/zfs/zfs-list.cache/"\${ROOT_POOL_NAME}" 
## 
# Fix the paths to eliminate /mnt:
sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/*"

# 6.1 Snapshot the initial installation
zfs snapshot "\${ROOT_POOL_NAME}"/ROOT/debian@install
zfs snapshot "\${BOOT_POOL_NAME}"/BOOT/debian@install

# 6.2 Exit from the chroot environment back to the LiveCD environment
exit
END_OF_CHROOT
chmod +x /mnt/usr/local/sbin/chroot_commands.sh
chroot /mnt /usr/bin/env bash /usr/local/sbin/chroot_commands.sh

# 6.3 Run these commands in the LiveCD environment to unmount all filesystems
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' |\
    xargs -i{} umount -lf {}
zpool export -a

# fixup for root pool not found following reboot =============
if ! zpool import -N "$ROOT_POOL_NAME" 
then
    zpool import -N -d "$ROOT_PART" "$ROOT_POOL_NAME" 
    echo "root pool fixup applied"
fi

zpool export -a
# =============


# 6.4 Reboot
echo reboot now

