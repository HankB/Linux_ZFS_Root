#!/bin/bash

# script to execute followingf first reboot of system
# (now booting to a ZFS root.)

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   echo "execute \"sudo -i\" and try again"
   exit 1
fi

set -e
set -u
set -x


# 6.6 Create a user account:
zfs create rpool/home/$YOURUSERNAME
adduser $YOURUSERNAME
cp -a /etc/skel/.[!.]* /home/$YOURUSERNAME
chown -R $YOURUSERNAME:$YOURUSERNAME /home/$YOURUSERNAME

usermod -a -G audio,cdrom,dip,floppy,netdev,plugdev,sudo,video $YOURUSERNAME

# 7.1 Create a volume dataset (zvol) for use as a swap device:
zfs create -V 16G -b $(getconf PAGESIZE) -o compression=zle \
      -o logbias=throughput -o sync=always \
      -o primarycache=metadata -o secondarycache=none \
      -o com.sun:auto-snapshot=false rpool/swap

# 7.2 Configure the swap device
mkswap -f /dev/zvol/rpool/swap
echo /dev/zvol/rpool/swap none swap defaults 0 0 >> /etc/fstab
#echo RESUME=none > /etc/initramfs-tools/conf.d/resume

# 7.3 Enable the swap device
swapon -av

# 8.1 Upgrade the minimal system
apt dist-upgrade --yes

# 8.2 Optional: Disable log compression
for file in /etc/logrotate.d/* ; do
    if grep -Eq "(^|[^#y])compress" "$file" ; then
        sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "$file"
    fi
done

# X.X my mod - install SSH server
apt install openssh-server

echo reboot and review Final Cleanup in the reference document

