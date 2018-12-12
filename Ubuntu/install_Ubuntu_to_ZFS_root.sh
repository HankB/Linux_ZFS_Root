#!/bin/bash

# 1.4 Become root:
# sudo -i
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   echo "execute \"sudo -i\" and try again"
   exit 1
fi

set -e
set -u
set -x

# 1.5 Install ZFS in the Live CD environment
apt install --yes debootstrap gdisk zfs-initramfs

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
    #exit 1
fi


# 2.3 Create the root pool
# 2.3a Unencrypted
zpool create -o ashift=12 \
      -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD \
      -O xattr=sa -O mountpoint=/ -R /mnt -f \
      rpool $ROOT_PART

# 3.1 Create a filesystem dataset to act as a container
zfs create -o canmount=off -o mountpoint=none rpool/ROOT

# 3.2 Create a filesystem dataset for the root filesystem
zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/ubuntu
zfs mount rpool/ROOT/ubuntu

# 3.3 Create datasets
zfs create                 -o setuid=off              rpool/home
zfs create -o canmount=off -o setuid=off  -o exec=off rpool/var
zfs create -o com.sun:auto-snapshot=false             rpool/var/cache
zfs create -o acltype=posixacl -o xattr=sa            rpool/var/log
zfs create                                            rpool/var/spool
zfs create -o com.sun:auto-snapshot=false -o exec=on  rpool/var/tmp

# If you use /srv on this system:
zfs create                                            rpool/srv

# If this system will have games installed:
zfs create                                            rpool/var/games

# If this system will store local email in /var/mail:
zfs create                                            rpool/var/mail

# If you will use Postfix, it requires exec=on for its chroot.  Choose:
# zfs inherit exec rpool/var
# OR
zfs create -o exec=on rpool/var/spool/postfix

# If this system will use NFS (locking):
zfs create -o com.sun:auto-snapshot=false \
             -o mountpoint=/var/lib/nfs                 rpool/var/nfs

# If you want a separate /tmp dataset (choose this now or tmpfs later):
zfs create -o com.sun:auto-snapshot=false \
             -o setuid=off                              rpool/tmp
chmod 1777 /mnt/tmp

# 3.5 Install the minimal system
chmod 1777 /mnt/var/tmp
debootstrap bionic /mnt
zfs set devices=off rpool

# 4.1 Configure the hostname (change HOSTNAME to the desired hostname).
echo $NEW_HOSTNAME > /mnt/etc/hostname
echo "127.0.1.1       $NEW_HOSTNAME" >> /mnt/etc/hosts
# Add a line:
# 127.0.1.1       HOSTNAME
# or if the system has a real name in DNS:
# 127.0.1.1       FQDN HOSTNAME
vi /mnt/etc/hosts

# 4.2 Configure the network interface:
# Find the interface name:
ip addr show

cat >/mnt/etc/netplan/${ETHERNET}.yaml <<EOF
network:
  version: 2
  ethernets:
    ${ETHERNET}:
      dhcp4: true
EOF

cat /mnt/etc/netplan/${ETHERNET}.yaml

# 4.3  Configure the package sources:
sed -i 's/^/# /' /mnt/etc/apt/sources.list
    # vi /mnt/etc/apt/sources.list

cat >> /mnt/etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu bionic main universe
deb-src http://archive.ubuntu.com/ubuntu bionic main universe

deb http://security.ubuntu.com/ubuntu bionic-security main universe
deb-src http://security.ubuntu.com/ubuntu bionic-security main universe

deb http://archive.ubuntu.com/ubuntu bionic-updates main universe
deb-src http://archive.ubuntu.com/ubuntu bionic-updates main universe
EOF

cat /mnt/etc/apt/sources.list

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
dpkg-reconfigure locales
dpkg-reconfigure tzdata

# 4.6 Install ZFS in the chroot environment for the new system
apt install --yes --no-install-recommends linux-image-generic
apt install --yes zfs-initramfs

# 4.8 Install GRUB
# 4.8b Install GRUB for UEFI booting
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
addgroup --system lpadmin
addgroup --system sambashare

# 4.10 Set a root password
passwd

# 4.11 Fix filesystem mount ordering
zfs set mountpoint=legacy rpool/var/log
zfs set mountpoint=legacy rpool/var/tmp
cat >> /etc/fstab << EOF
rpool/var/log /var/log zfs noatime,nodev,noexec,nosuid 0 0
rpool/var/tmp /var/tmp zfs noatime,nodev,nosuid 0 0
EOF

# If you created a /tmp dataset, do the same for it:
zfs set mountpoint=legacy rpool/tmp
cat >> /etc/fstab << EOF
rpool/tmp /tmp zfs noatime,nodev,nosuid 0 0
EOF

# 5.1 Verify that the ZFS root filesystem is recognized
if ! [ \`grub-probe /\` == "zfs" ];then
    echo "grub-probe != zfs"
    exit 1
fi

# 5.2 Refresh the initrd files
update-initramfs -u -k all

# 5.3 Optional (but highly recommended): Make debugging GRUB easier
sed -i "s/GRUB_TIMEOUT_STYLE/### GRUB_TIMEOUT_STYLE/" /etc/default/grub
sed -i "s/quiet splash/ /" /etc/default/grub
sed -i "s/#GRUB_TERMINAL/GRUB_TERMINAL/" /etc/default/grub
cat /etc/default/grub

# 5.4 Update the boot configuration
update-grub

# 5.5 Install the boot loader
# 5.5b For UEFI booting, install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
      --bootloader-id=ubuntu --recheck --no-floppy

# 5.6 Verify that the ZFS module is installed
ls /boot/grub/*/zfs.mod

# 6.1 Snapshot the initial installation
zfs snapshot rpool/ROOT/ubuntu@install

# 6.2 Exit from the chroot environment back to the LiveCD environment
exit
END_OF_CHROOT
chmod +x /mnt/usr/local/sbin/chroot_commands.sh
chroot /mnt /usr/local/sbin/chroot_commands.sh

# 6.3 Run these commands in the LiveCD environment to unmount all filesystems
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export rpool

# 6.4 Reboot
# reboot

