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
# set -x            # expand commands - for debugging

if [ "$#"  == 0 ]; then
    echo 'using default ENV vars (env.sh)'
    source env.sh
else
    echo Getting ENV vars from $1
    source $1
fi

# Verify consistency of ENV vars

# Make sure $BACKPORTS is set to something, default to 'no'
if [ -z ${BACKPORTS+x} ]
then
    export BACKPORTS="no"
fi

# Make sure $EXPERIMENTAL is set to something, default to 'no'
if [ -z ${EXPERIMENTAL+x} ]
then
    export EXPERIMENTAL="no"
fi

# Make sure $ENCRYPT is set to something, default to 'no'
if [ -z ${ENCRYPT+x} ]
then
    export ENCRYPT="no"
fi


if [ "$BACKPORTS" = "yes" -a "$EXPERIMENTAL" = "yes" ]
then
    echo "cannot set both BACKPORTS and EXPERIMENTAL tro \"yes\""
    exit 1
fi


# 1.4 Add contrib archive area
if [ -e /etc/apt/sources.list ] 
then
    echo deb http://deb.debian.org/debian buster contrib >> /etc/apt/sources.list
else
    if [ -d /etc/apt/sources.list.d ]
    then
        echo "deb http://deb.debian.org/debian buster main contrib" > /etc/apt/sources.list.d/contrib.list
    else
        echo "can't find sources file"
        exit 1
    fi
fi

# Optional

if [ "$BACKPORTS" = "yes" ]
then
    cat > /etc/apt/sources.list.d/buster-backports.list <<EOF
    deb http://deb.debian.org/debian buster-backports main contrib
    deb-src http://deb.debian.org/debian buster-backports main contrib
EOF

    cat >  /etc/apt/preferences.d/90_zfs <<EOF
    Package: libnvpair1linux libuutil1linux libzfs2linux libzpool2linux spl-dkms zfs-dkms zfs-test zfsutils-linux zfsutils-linux-dev zfs-zed
    Pin: release n=buster-backports
    Pin-Priority: 990
EOF
fi

apt update

# 1.5 Install ZFS in the Live CD environment
apt install --yes debootstrap gdisk dpkg-dev linux-headers-$(uname -r)
if [ "$BACKPORTS" = "yes" ]
then
    apt install --yes -t buster-backports zfs-dkms
else
    if [ "$EXPERIMENTAL" = "yes" ]
    then
        apt install --yes debootstrap gdisk dpkg-dev linux-headers-$(uname -r)
        apt install --yes git-buildpackage build-essential libattr1-dev \
        libblkid-dev libselinux1-dev libssl-dev python3-cffi python3-setuptools \
        python3-sphinx python3-all-dev uuid-dev zlib1g-dev \
        libaio-dev libelf-dev libudev-dev
        git clone https://salsa.debian.org/zfsonlinux-team/zfs.git
        cd zfs
        git checkout pristine-tar
        git checkout master
        gbp buildpackage -uc -us
        cd ..
        dpkg --install \
            libnvpair1linux_0.8.1-4_amd64.deb \
            libuutil1linux_0.8.1-4_amd64.deb \
            libzfs2linux_0.8.1-4_amd64.deb \
            libzpool2linux_0.8.1-4_amd64.deb \
            zfs-dkms_0.8.1-4_all.deb \
            zfsutils-linux_0.8.1-4_amd64.deb \
            zfs-zed_0.8.1-4_amd64.deb
    else
        apt install --yes zfs-dkms
    fi
fi
modprobe zfs

# 2.2 Partition your disk

if [ $INSTALL_TYPE == "whole_disk" ];then
    # 2.1 If you are re-using a disk, clear it as necessary
    wipefs -a /dev/disk/by-id/$DRIVE_ID     # useful if the drive already had ZFS pools
    sgdisk --zap-all /dev/disk/by-id/$DRIVE_ID

    # 2.2 Partition your disk
    # Run this for UEFI booting (for use now or in the future):
    sgdisk     -n2:1M:+1024M -t2:EF00 /dev/disk/by-id/$DRIVE_ID
    export EFI_PART=/dev/disk/by-id/${DRIVE_ID}-part2

    # Run this for the boot pool:
    sgdisk     -n3:0:+1024M    -t3:BF01 /dev/disk/by-id/$DRIVE_ID
    export BOOT_PART=/dev/disk/by-id/${DRIVE_ID}-part3

    if [[  $ENCRYPT == "yes" && "$BACKPORTS" == "no" && "$EXPERIMENTAL" == "no" ]]; then
        # 2.2b LUKS:
        sgdisk     -n4:0:0      -t4:8300 /dev/disk/by-id/$DRIVE_ID
    else 
        # 2.2a Unencrypted
        sgdisk     -n4:0:0      -t4:BF01 /dev/disk/by-id/$DRIVE_ID
    fi
    export ROOT_PART=/dev/disk/by-id/${DRIVE_ID}-part4
    partprobe  /dev/disk/by-id/$DRIVE_ID
    sleep 3 # avoid '$BOOT_PART': No such file or directory 
elif [ $INSTALL_TYPE == "use_partitions" ];then
    echo "using $ROOT_PART for root partition"
    echo "using $BOOT_PART for boot partition"
    wipefs -a $ROOT_PART     # useful if the partition already had ZFS pools
    wipefs -a $BOOT_PART     # useful if the partition already had ZFS pools
    echo "using $EFI_PART for EFI partition"
elif [ $INSTALL_TYPE == "use_pools" ];then
    echo "using $ROOT_POOL_NAME for root pool"
    echo "using $BOOT_POOL_NAME for boot pool"
    echo "using $EFI_PART for EFI partition"

else
    echo set INSTALL_TYPE to \"whole_disk\" or \"use_partitions\" or \"use_pools\"
    exit 1
fi

if [ $INSTALL_TYPE != "use_pools" ];then 
    # 2.3 Create the boot pool
    if [[ "$EXPERIMENTAL" == "yes" || "$BACKPORTS" == "yes" ]]
    then
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
            ${BOOT_POOL_NAME} $BOOT_PART
    else
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
    fi

    # 2.4 Create the root pool
    if [ $ENCRYPT == "no" ]; then

        # 2.4a Unencrypted
        zpool create -o ashift=12 \
            -O acltype=posixacl -O canmount=off -O compression=lz4 \
            -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
            -O mountpoint=/ -R /mnt -f \
            ${ROOT_POOL_NAME} $ROOT_PART
    elif [ $ENCRYPT == "yes" ]; then
        if [[ "$EXPERIMENTAL" == "yes" || "$BACKPORTS" == "yes" ]]
        then
            # native ZFS encryption
            zpool create -o ashift=12 \
                -O acltype=posixacl -O canmount=off -O compression=lz4 \
                -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
                -O encryption=aes-256-gcm -O keylocation=prompt -O keyformat=passphrase \
                -O mountpoint=/ -R /mnt -f \
                ${ROOT_POOL_NAME} $ROOT_PART
        else
            # 2.4b LUKS:
            apt install --yes cryptsetup
            cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha256 $ROOT_PART
            cryptsetup luksOpen $ROOT_PART luks1
            zpool create -o ashift=12 \
                -O acltype=posixacl -O canmount=off -O compression=lz4 \
                -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
                -O mountpoint=/ -R /mnt -f \
                ${ROOT_POOL_NAME} /dev/mapper/luks1
            # TODO make 'luks1' an ENV var to manage the situation when there are other
            # encrypted partitions. Or find the first available (unused) luks device.
        fi
    else
        echo "Set ENCRYPT to \"yes\" or \"no\""
        exit 1
    fi
fi

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
debootstrap buster /mnt http://deb.debian.org/debian
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
deb http://deb.debian.org/debian buster main contrib
deb-src http://deb.debian.org/debian buster main contrib

deb http://security.debian.org/debian-security buster/updates main contrib
deb-src http://security.debian.org/debian-security buster/updates main contrib

EOF

# Optional
if [ "$BACKPORTS" = "yes" ]
then
    cat > /mnt/etc/apt/sources.list.d/buster-backports.list <<EOF
    deb http://deb.debian.org/debian buster-backports main contrib
    deb-src http://deb.debian.org/debian buster-backports main contrib
EOF

    cat >  /mnt/etc/apt/preferences.d/90_zfs <<EOF
    Package: libnvpair1linux libuutil1linux libzfs2linux libzpool2linux spl-dkms zfs-dkms zfs-test zfsutils-linux zfsutils-linux-dev zfs-zed
    Pin: release n=buster-backports
    Pin-Priority: 990
EOF
fi


# 4.4  Bind the virtual filesystems from the LiveCD environment to the new system
# and `chroot` into it:

mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys

#chroot /mnt /bin/bash --login

# Build a script to run in the chroot enbvironment
cat <<END_OF_CHROOT >/mnt/usr/local/sbin/chroot_commands.sh
#!/bin/bash

set -euo pipefail
# set -e            # exit on error
# set -u            # treat unset variables as errors
# set -o pipefail   # check exit status of all commands in pipeline
# set -x            # expand commands - for debugging

# 4.5 Configure a basic system environment
ln -s /proc/self/mounts /etc/mtab
apt update
apt install --yes locales
dpkg-reconfigure locales
dpkg-reconfigure tzdata

# 4.6 Install ZFS in the chroot environment for the new system
apt install --yes dpkg-dev linux-headers-amd64 linux-image-amd64
if [ "\$EXPERIMENTAL" = "yes" ]
then

    apt install --yes git-buildpackage build-essential dkms libattr1-dev \
    libblkid-dev libselinux1-dev libssl-dev python3-cffi python3-setuptools \
    python3-sphinx python3-all-dev uuid-dev zlib1g-dev \
    libaio-dev libelf-dev libudev-dev
    cd /root
    git clone https://salsa.debian.org/zfsonlinux-team/zfs.git
    cd zfs
    git checkout pristine-tar
    git checkout master
    gbp buildpackage -uc -us
    cd ..
    dpkg --install \
        libnvpair1linux_0.8.1-4_amd64.deb \
        libuutil1linux_0.8.1-4_amd64.deb \
        libzfs2linux_0.8.1-4_amd64.deb \
        libzpool2linux_0.8.1-4_amd64.deb \
        zfs-dkms_0.8.1-4_all.deb \
        zfs-initramfs_0.8.1-4_all.deb \
        zfsutils-linux_0.8.1-4_amd64.deb \
        zfs-zed_0.8.1-4_amd64.deb
else
    if [ "\$BACKPORTS" = "yes" ]
    then
        apt install --yes -t buster-backports zfs-initramfs
    else 
        apt install --yes zfs-initramfs
    fi
        # 4.7 For LUKS installs only, setup crypttab:
        if [ "\$ENCRYPT" = "yes" ]; then
            apt install --yes cryptsetup
            echo luks1 UUID=\$(blkid -s UUID -o value  \$ROOT_PART) none \
                luks,discard,initramfs > /etc/crypttab
        fi
    fi
fi
# 4.7 Install GRUB
# 4.7b Install GRUB for UEFI booting
if [ \$INSTALL_TYPE == "whole_disk" ];then
    apt install dosfstools
    mkdosfs -F 32 -s 1 -n EFI \${EFI_PART}
fi
mkdir /boot/efi
echo \${EFI_PART} \
      /boot/efi vfat nofail,x-systemd.device-timeout=1 0 1 >> /etc/fstab
mount /boot/efi
apt install --yes grub-efi-amd64 shim-signed

# 4.9 Setup system groups
# addgroup --system lpadmin
# addgroup --system sambashare

# 4.9 Set a root password
echo "set a root password"
set +e
while ! passwd 
do
	echo $?
	echo try again
done
set -e

# 4.10 Enable importing bpool
cat <<EOF >/etc/systemd/system/zfs-import-\${BOOT_POOL_NAME}.service
[Unit]
DefaultDependencies=no
Before=zfs-import-scan.service
Before=zfs-import-cache.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/zpool import -N -o cachefile=none \${BOOT_POOL_NAME}

[Install]
WantedBy=zfs-import.target
EOF

systemctl enable zfs-import-\${BOOT_POOL_NAME}.service

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


if [ "\$EXPERIMENTAL" = "yes" ]
then
    zfs set mountpoint=legacy bpool/BOOT/debian
    echo bpool/BOOT/debian /boot zfs \
        nodev,relatime,x-systemd.requires=zfs-import-bpool.service 0 0 >> /etc/fstab

    mkdir /etc/zfs/zfs-list.cache
    touch /etc/zfs/zfs-list.cache/rpool
    ln -s /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d
    zed -F &
    ZED_PID=\$!

    # Verify that zed updated the cache by making sure this is not empty:
    cat /etc/zfs/zfs-list.cache/rpool

    # If it is empty, force a cache update and check again:
    zfs set canmount=noauto rpool/ROOT/debian

    # Stop zed:
    # fg
    # Press Ctrl-C.
    sleep 5 # does zed need time to work?
    kill \$ZED_PID

    # Fix the paths to eliminate /mnt:
    sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/rpool
else
    zfs set mountpoint=legacy \${BOOT_POOL_NAME}/BOOT/debian
    echo \${BOOT_POOL_NAME}/BOOT/debian /boot zfs \
        nodev,relatime,x-systemd.requires=zfs-import-${BOOT_POOL_NAME}.service 0 0 >> /etc/fstab

    zfs set mountpoint=legacy \${ROOT_POOL_NAME}/var/log
    echo \${ROOT_POOL_NAME}/var/log /var/log zfs nodev,relatime 0 0 >> /etc/fstab

    zfs set mountpoint=legacy \${ROOT_POOL_NAME}/var/spool
    echo \${ROOT_POOL_NAME}/var/spool /var/spool zfs nodev,relatime 0 0 >> /etc/fstab

    # If you created a /var/tmp dataset:
    zfs set mountpoint=legacy \${ROOT_POOL_NAME}/var/tmp
    echo \${ROOT_POOL_NAME}/var/tmp /var/tmp zfs nodev,relatime 0 0 >> /etc/fstab

    # If you created a /tmp dataset:
    # zfs set mountpoint=legacy ${ROOT_POOL_NAME}/tmp
    # echo \${ROOT_POOL_NAME}/tmp /tmp zfs nodev,relatime 0 0 >> /etc/fstab
fi

# 6.1 Snapshot the initial installation
zfs snapshot \${ROOT_POOL_NAME}/ROOT/debian@install
zfs snapshot \${BOOT_POOL_NAME}/BOOT/debian@install

# 6.2 Exit from the chroot environment back to the LiveCD environment
exit
END_OF_CHROOT
chmod +x /mnt/usr/local/sbin/chroot_commands.sh
chroot /mnt /usr/local/sbin/chroot_commands.sh

# 6.3 Run these commands in the LiveCD environment to unmount all filesystems
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export -a

# 6.4 Reboot
echo reboot now

