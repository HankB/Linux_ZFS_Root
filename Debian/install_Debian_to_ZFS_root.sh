#!/bin/bash

# 1.3 Become root:
# sudo -i
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   echo "execute \"sudo -i\" and try again"
   exit 1
fi

set -e
set -u
set -x

# 1.4 Add contrib archive area
if [ -e /etc/apt/sources.list ] 
then
    echo "deb http://ftp.debian.org/debian stretch main contrib" > /etc/apt/sources.list
else
    if [ -d /etc/apt/sources.list.d ]
    then
        echo "deb http://ftp.debian.org/debian stretch main contrib" > /etc/apt/sources.list.d/zfs-contrib.list
    else
        echo "can't find sources file"
        exit 1
    fi
fi
apt update

# 1.5 Install ZFS in the Live CD environment
apt install --yes debootstrap gdisk dpkg-dev linux-headers-$(uname -r)
apt install --yes zfs-dkms
modprobe zfs

# 2.2 Partition your disk

if [ $USE_EXISTING_PART == "no" ];then
    # 2.1 If you are re-using a disk, clear it as necessary
    sgdisk --zap-all /dev/disk/by-id/$DRIVE_ID

    # 2.2 Partition your disk
    # Run this for UEFI booting (for use now or in the future):
    sgdisk     -n3:1M:+512M -t3:EF00 /dev/disk/by-id/$DRIVE_ID
    export EFI_PART=/dev/disk/by-id/${DRIVE_ID}-part3

    # 2.2a Unencrypted
    sgdisk     -n1:0:0      -t1:BF01 /dev/disk/by-id/$DRIVE_ID
    export ROOT_PART=/dev/disk/by-id/${DRIVE_ID}-part1
    partprobe  /dev/disk/by-id/$DRIVE_ID
elif [ $USE_EXISTING_PART == "yes" ];then
    echo "using $ROOT_PART for root"
    echo "using $EFI_PART for EFI"
else
    echo set USE_EXISTING_PART to \"yes\" or \"no\"
    exit 1
fi


# 2.3 Create the root pool
# 2.3a Unencrypted
zpool create -o ashift=12 \
      -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD \
      -O xattr=sa -O mountpoint=/ -R /mnt -f \
      ${POOLNAME} $ROOT_PART

# 3.1 Create a filesystem dataset to act as a container
zfs create -o canmount=off -o mountpoint=none ${POOLNAME}/ROOT

# 3.2 Create a filesystem dataset for the root filesystem
zfs create -o canmount=noauto -o mountpoint=/ ${POOLNAME}/ROOT/debian
zfs mount ${POOLNAME}/ROOT/debian

# 3.3 Create datasets
zfs create                 -o setuid=off              ${POOLNAME}/home
zfs create -o mountpoint=/root                        ${POOLNAME}/home/root
zfs create -o canmount=off -o setuid=off  -o exec=off ${POOLNAME}/var
zfs create -o com.sun:auto-snapshot=false             ${POOLNAME}/var/cache
zfs create                                            ${POOLNAME}/var/log
zfs create                                            ${POOLNAME}/var/spool
zfs create -o com.sun:auto-snapshot=false -o exec=on  ${POOLNAME}/var/tmp

# If you use /srv on this system:
zfs create                                            ${POOLNAME}/srv

# If this system will have games installed:
zfs create                                            ${POOLNAME}/var/games

# If this system will store local email in /var/mail:
zfs create                                            ${POOLNAME}/var/mail

# If you will use Postfix, it requires exec=on for its chroot.  Choose:
# zfs inherit exec ${POOLNAME}/var
# OR
zfs create -o exec=on ${POOLNAME}/var/spool/postfix

# If this system will use NFS (locking):
zfs create -o com.sun:auto-snapshot=false \
             -o mountpoint=/var/lib/nfs                 ${POOLNAME}/var/nfs

# If you want a separate /tmp dataset (choose this now or tmpfs later):
zfs create -o com.sun:auto-snapshot=false \
             -o setuid=off                              ${POOLNAME}/tmp
chmod 1777 /mnt/tmp

# 3.5 Install the minimal system
chmod 1777 /mnt/var/tmp
debootstrap stretch /mnt
zfs set devices=off ${POOLNAME}

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
apt install --yes dpkg-dev linux-headers-$(uname -r) linux-image-amd64
apt install --yes zfs-dkms zfs-initramfs

# 4.7 Install GRUB
# 4.7b Install GRUB for UEFI booting
if [ $USE_EXISTING_PART == "no" ];then
    apt install dosfstools
    mkdosfs -F 32 -n EFI ${EFI_PART}
fi
mkdir /boot/efi
echo PARTUUID=$(blkid -s PARTUUID -o value \
      ${EFI_PART}) \
      /boot/efi vfat noatime,nofail,x-systemd.device-timeout=1 0 1 >> /etc/fstab
mount /boot/efi
apt install --yes grub-efi-amd64

# 4.9 Setup system groups
# addgroup --system lpadmin
# addgroup --system sambashare

# 4.7 [sic] Set a root password
passwd

# 4.8 Fix filesystem mount ordering
zfs set mountpoint=legacy ${POOLNAME}/var/log
zfs set mountpoint=legacy ${POOLNAME}/var/tmp
cat >> /etc/fstab << EOF
${POOLNAME}/var/log /var/log zfs noatime,nodev,noexec,nosuid 0 0
${POOLNAME}/var/tmp /var/tmp zfs noatime,nodev,nosuid 0 0
EOF

# If you created a /tmp dataset, do the same for it:
zfs set mountpoint=legacy ${POOLNAME}/tmp
cat >> /etc/fstab << EOF
${POOLNAME}/tmp /tmp zfs noatime,nodev,nosuid 0 0
EOF

# 5.1 Verify that the ZFS root filesystem is recognized
if ! [ \`grub-probe /\` == "zfs" ];then
    echo "grub-probe != zfs"
    exit 1
fi

# 5.2 Refresh the initrd files
update-initramfs -u -k all

# 5.3 Optional (but highly recommended): Make debugging GRUB easier
# sed -i "s/GRUB_TIMEOUT_STYLE/### GRUB_TIMEOUT_STYLE/" /etc/default/grub
sed -i "s/quiet / /" /etc/default/grub
sed -i "s/#GRUB_TERMINAL/GRUB_TERMINAL/" /etc/default/grub
vi /etc/default/grub

# 5.4 Update the boot configuration
update-grub

# 5.5 Install the boot loader
# 5.5b For UEFI booting, install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
      --bootloader-id=debian --recheck --no-floppy

# 5.6 Verify that the ZFS module is installed
ls /boot/grub/*/zfs.mod

# 6.1 Snapshot the initial installation
zfs snapshot ${POOLNAME}/ROOT/debian@install

# 6.2 Exit from the chroot environment back to the LiveCD environment
exit
END_OF_CHROOT
chmod +x /mnt/usr/local/sbin/chroot_commands.sh
chroot /mnt /usr/local/sbin/chroot_commands.sh

# 6.3 Run these commands in the LiveCD environment to unmount all filesystems
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export ${POOLNAME}

# 6.4 Reboot
# reboot

