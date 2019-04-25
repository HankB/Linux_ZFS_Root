#!/bin/bash

# 1.3 Become root:
# sudo -i
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   echo "execute \"sudo -i\" and try again"
   exit 1
fi

set -e      # exit on error
set -u      # treat unset variables as errors
set -x      # expand commands

# 1.4 Add contrib archive area
if [ -e /etc/apt/sources.list ] 
then
    echo deb http://ftp.debian.org/debian stretch contrib > /etc/apt/sources.list
    echo deb http://deb.debian.org/debian stretch-backports main contrib >> /etc/apt/sources.list
else
    if [ -d /etc/apt/sources.list.d ]
    then
        echo "deb http://ftp.debian.org/debian stretch main contrib" > /etc/apt/sources.list.d/contrib.list
        echo deb http://deb.debian.org/debian stretch-backports main contrib > /etc/apt/sources.list.d/backports.list
    else
        echo "can't find sources file"
        exit 1
    fi
fi
apt update

# 1.5 Install ZFS in the Live CD environment
apt install --yes debootstrap gdisk dkms dpkg-dev linux-headers-$(uname -r)
apt install --yes -t stretch-backports zfs-dkms
modprobe zfs

# 2.2 Partition your disk

if [ $USE_EXISTING_PART == "no" ];then
    # 2.1 If you are re-using a disk, clear it as necessary
    wipefs -a /dev/disk/by-id/$DRIVE_ID     # useful if the drive already had ZFS pools
    sgdisk --zap-all /dev/disk/by-id/$DRIVE_ID

    # 2.2 Partition your disk
    # Run this for UEFI booting (for use now or in the future):
    sgdisk     -n2:1M:+512M -t2:EF00 /dev/disk/by-id/$DRIVE_ID
    export EFI_PART=/dev/disk/by-id/${DRIVE_ID}-part2

    # Run this for the boot pool:
    sgdisk     -n3:0:+512M    -t3:BF01 /dev/disk/by-id/$DRIVE_ID
    export BOOT_PART=/dev/disk/by-id/${DRIVE_ID}-part3

    # 2.2a Unencrypted
    sgdisk     -n4:0:0      -t4:BF01 /dev/disk/by-id/$DRIVE_ID
    export ROOT_PART=/dev/disk/by-id/${DRIVE_ID}-part4
    partprobe  /dev/disk/by-id/$DRIVE_ID
elif [ $USE_EXISTING_PART == "yes" ];then
    echo "using $ROOT_PART for root"
    echo "using $BOOT_PART for boot"
    wipefs -a $ROOT_PART     # useful if the partition already had ZFS pools
    wipefs -a $BOOT_PART     # useful if the partition already had ZFS pools
    echo "using $EFI_PART for EFI"
else
    echo set USE_EXISTING_PART to \"yes\" or \"no\"
    exit 1
fi


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
      -O acltype=posixacl -O canmount=off -O compression=lz4 -O devices=off \
      -O normalization=formD -O relatime=on -O xattr=sa \
      -O mountpoint=/ -R /mnt -f \
      ${BOOT_POOL_NAME} $BOOT_PART

# 2.4 Create the root pool
# 2.4a Unencrypted
zpool create -o ashift=12 \
      -O acltype=posixacl -O canmount=off -O compression=lz4 \
      -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
      -O mountpoint=/ -R /mnt -f \
      ${ROOT_POOL_NAME} $ROOT_PART


# 3.1 Create filesystem datasets to act as containers
zfs create -o canmount=off -o mountpoint=none ${ROOT_POOL_NAME}/ROOT
zfs create -o canmount=off -o mountpoint=none ${BOOT_POOL_NAME}/BOOT

# 3.2 Create a filesystem datasets for the root and boot filesystems
zfs create -o canmount=noauto -o mountpoint=/ ${ROOT_POOL_NAME}/ROOT/debian
zfs mount ${ROOT_POOL_NAME}/ROOT/debian

zfs create -o canmount=noauto -o mountpoint=/boot ${BOOT_POOL_NAME}/BOOT/debian
zfs mount ${BOOT_POOL_NAME}/BOOT/debian

# 3.3 Create datasets
zfs create                                            ${ROOT_POOL_NAME}/home
zfs create -o mountpoint=/root                        ${ROOT_POOL_NAME}/home/root
zfs create -o canmount=off                            ${ROOT_POOL_NAME}/var
zfs create -o canmount=off                            ${ROOT_POOL_NAME}/var/lib
zfs create                                            ${ROOT_POOL_NAME}/var/log
zfs create                                            ${ROOT_POOL_NAME}/var/spool
# If you wish to exclude these from snapshots:
zfs create -o com.sun:auto-snapshot=false             ${ROOT_POOL_NAME}/var/cache
zfs create -o com.sun:auto-snapshot=false             ${ROOT_POOL_NAME}/var/tmp
chmod 1777 /mnt/var/tmp

# If you use /opt on this system:
zfs create                                            ${ROOT_POOL_NAME}/opt

# If you use /srv on this system:
zfs create                                            ${ROOT_POOL_NAME}/srv

# If you use /usr/local on this system:
zfs create -o canmount=off                            ${ROOT_POOL_NAME}/usr
zfs create                                            ${ROOT_POOL_NAME}/usr/local

# If this system will have games installed:
zfs create                                            ${ROOT_POOL_NAME}/var/games

# If this system will store local email in /var/mail:
zfs create                                            ${ROOT_POOL_NAME}/var/mail

# If this system will use Snap packages:
zfs create                                            ${ROOT_POOL_NAME}/var/snap

# If you use /var/www on this system:
zfs create                                            ${ROOT_POOL_NAME}/var/www

# If this system will use GNOME:
zfs create                                            ${ROOT_POOL_NAME}/var/lib/AccountsService

# If this system will use Docker (which manages its own datasets & snapshots):
zfs create -o com.sun:auto-snapshot=false             ${ROOT_POOL_NAME}/var/lib/docker

# If this system will use NFS (locking):
zfs create -o com.sun:auto-snapshot=false             ${ROOT_POOL_NAME}/var/lib/nfs

# A tmpfs is recommended later, but if you want a separate dataset for /tmp:
# zfs create -o com.sun:auto-snapshot=false  rpool/tmp
# chmod 1777 /mnt/tmp

# 3.4 Install the minimal system
debootstrap stretch /mnt
zfs set devices=off ${ROOT_POOL_NAME}

# 4.1 Configure the hostname (change HOSTNAME to the desired hostname).
echo $NEW_HOSTNAME > /mnt/etc/hostname
echo "127.0.1.1       $NEW_HOSTNAME" >> /mnt/etc/hosts
# Add a line:
# 127.0.1.1       HOSTNAME
# or if the system has a real name in DNS:
# 127.0.1.1       FQDN HOSTNAME

# 4.2 Configure the network interface:
# Find the interface name:
ip addr show

cat >/mnt/etc/network/interfaces.d/${ETHERNET} <<EOF
auto ${ETHERNET}
iface ${ETHERNET} inet dhcp
EOF

cat /mnt/etc/network/interfaces.d/${ETHERNET}

# 4.3  Configure the package sources:
# Add `contrib` archive area:
sed -i "s/^/# /" /mnt/etc/apt/sources.list
cat <<EOF >> /mnt/etc/apt/sources.list
deb http://ftp.debian.org/debian stretch main contrib
deb-src http://ftp.debian.org/debian stretch main contrib
EOF

cat <<EOF >/mnt/etc/apt/sources.list.d/stretch-backports.list
deb http://deb.debian.org/debian stretch-backports main contrib
deb-src http://deb.debian.org/debian stretch-backports main contrib
EOF

# Add backports
cat <<EOF >/mnt/etc/apt/preferences.d/90_zfs
Package: libnvpair1linux libuutil1linux libzfs2linux libzpool2linux spl-dkms zfs-dkms zfs-test zfsutils-linux zfsutils-linux-dev zfs-zed
Pin: release n=stretch-backports
Pin-Priority: 990
EOF

# 4.4  Bind the virtual filesystems from the LiveCD environment to the new system
# and `chroot` into it:

mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys

#chroot /mnt /bin/bash --login

# following commands have to be copied/pasted to execute inside the chroot
cat <<END_OF_CHROOT >/mnt/usr/local/sbin/chroot_commands.sh
#!/bin/bash
set -e
set -u
set -x

# 4.5 Configure a basic system environment
ln -s /proc/self/mounts /etc/mtab
apt update
apt install --yes locales
dpkg-reconfigure locales
dpkg-reconfigure tzdata

# 4.6 Install ZFS in the chroot environment for the new system
apt install --yes dpkg-dev linux-headers-amd64 linux-image-amd64
apt install --yes zfs-initramfs

# 4.7 Install GRUB
# 4.7b Install GRUB for UEFI booting
if [ $USE_EXISTING_PART == "no" ];then
    apt install dosfstools
    mkdosfs -F 32 -s 1 -n EFI ${EFI_PART}
fi
mkdir /boot/efi
echo PARTUUID=$(blkid -s PARTUUID -o value \
      ${EFI_PART}) \
      /boot/efi vfat nofail,x-systemd.device-timeout=1 0 1 >> /etc/fstab
mount /boot/efi
apt install --yes grub-efi-amd64 shim

# 4.9 Setup system groups
# addgroup --system lpadmin
# addgroup --system sambashare

# 4.9 [sic] Set a root password
echo "set a root password"
passwd

# 4.10 Enable importing bpool
cat <<EOF >/etc/systemd/system/zfs-import-${BOOT_POOL_NAME}.service
[Unit]
DefaultDependencies=no
Before=zfs-import-scan.service
Before=zfs-import-cache.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/zpool import -N -o cachefile=none ${BOOT_POOL_NAME}

[Install]
WantedBy=zfs-import.target
EOF

systemctl enable zfs-import-${BOOT_POOL_NAME}.service

# 4.11 Optional (but recommended): Mount a tmpfs to /tmp
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

# 4.12 Optional (but kindly requested): Install popcon
apt install --yes popularity-contest

# 5.1 Verify that the ZFS root filesystem is recognized
if ! [ \`grub-probe /boot\` == "zfs" ];then
    echo "grub-probe != zfs"
    exit 1
fi

# 5.2 Refresh the initrd files
update-initramfs -u -k all

# 5.3 Workaround GRUB's missing zpool-features support:
sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"root=ZFS=rpool\/ROOT\/debian /" /etc/default/grub

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

zfs set mountpoint=legacy ${BOOT_POOL_NAME}/BOOT/debian
echo ${BOOT_POOL_NAME}/BOOT/debian /boot zfs \
    nodev,relatime,x-systemd.requires=zfs-import-${BOOT_POOL_NAME}.service 0 0 >> /etc/fstab

zfs set mountpoint=legacy ${ROOT_POOL_NAME}/var/log
echo ${ROOT_POOL_NAME}/var/log /var/log zfs nodev,relatime 0 0 >> /etc/fstab

zfs set mountpoint=legacy ${ROOT_POOL_NAME}/var/spool
echo ${ROOT_POOL_NAME}/var/spool /var/spool zfs nodev,relatime 0 0 >> /etc/fstab

# If you created a /var/tmp dataset:
zfs set mountpoint=legacy ${ROOT_POOL_NAME}/var/tmp
echo ${ROOT_POOL_NAME}/var/tmp /var/tmp zfs nodev,relatime 0 0 >> /etc/fstab

# If you created a /tmp dataset:
# zfs set mountpoint=legacy ${ROOT_POOL_NAME}/tmp
# echo ${ROOT_POOL_NAME}/tmp /tmp zfs nodev,relatime 0 0 >> /etc/fstab

# 6.1 Snapshot the initial installation
zfs snapshot ${ROOT_POOL_NAME}/ROOT/debian@install
zfs snapshot ${BOOT_POOL_NAME}/BOOT/debian@install

# 6.2 Exit from the chroot environment back to the LiveCD environment
exit
END_OF_CHROOT
chmod +x /mnt/usr/local/sbin/chroot_commands.sh
chroot /mnt /usr/local/sbin/chroot_commands.sh

# 6.3 Run these commands in the LiveCD environment to unmount all filesystems
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export ${ROOT_POOL_NAME}

# 6.4 Reboot
# reboot

