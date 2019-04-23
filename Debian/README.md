# Debian ZFS Root

Script to facilitate installing Debian Stretch on a ZFS root.

## Inspiration

[Debian Stretch Root on ZFS
](https://github.com/zfsonlinux/zfs/wiki/Debian-Stretch-Root-on-ZFS) as of 2018-10-09.

## Motivation

Provide a script to install Debian on ZFS side by side with Windows 10. Instructions in the link above describe how to do this using Debian for the whole disk. With appropriate modifications it can be performed with preconfigured partitions.

Second... I have difficulty following detailed instructions. In the long run it is easier to script the instructions. It takes a little more time up front but can then be easily repeated when desired.

## Status

Started migrating script produced to install Ubuntu.

Note: As of Rickard Laager's email to zfs-discuss@list.zfsonlinux.org on Mar 18, 2019, 10:57 PM this script is no longer synchronized with the instructions referenced above. The script may still work (It did for me) but will not utilize the most recent improvements in the procedure.

Work is in progress to update to the instructions as of 2019-04-18. The present version has been successfully tested (oncd!) for full disk install. Work is proceding with dual boot (Windows/Debina on ZFS) install.

## WARNING WILL ROBINSON

**If something goes wrong this script *will* destroy any data on any target system drive.** I captured a full disk image backup before testing this on any of my systems. Taking a full image backup takes less time than reinstalling Windows should that be needed.

Needless to say, I am not responsible for any data loss incurred as a result of using this S/W. Ise at your own risk and take appropriate precautions to backup your data.

### Other potential issues

This process does not support encryption. Nor does it support legacy boot.

This process does not decommission an existing MD RAID (See step 2.1) Itr will zap any existing partitions on the selected drive (if `$USE_EXISTING_PART == "no"`)

If using an existing partition, it will create the pool on the indicated partition. There is not yet support to use an existing pool. It will also not create the EFI partition but will create the bpool. (Subject to change...)

Pools are created with `-o ashift=12`. For SSDs and perhaps even other drives `ashift=13` may be better. Edit the script to accomplish this.

Uses `tmpfs` for `/tmp`.

Uses simple host name (step 4.1)

`popcon` (popularity contest) installed by default.

## Usage

### ENV variables

These determine how the install is processed. The most import one is USE_EXISTING_PART which determines if the entire disk is formatted as a ZFS pool or if an existing partition
is to be used. Getting this wrong could destroy existing data on the drive. Two examples of settings are shown.

#### Using an existing partition (e.g. dual or multi-boot.)

```shell
export ETHERNET=enp3s0
export NEW_HOSTNAME=rocinante
export YOURUSERNAME=hbarta
export ROOT_POOL_NAME=rpool
export BOOT_POOL_NAME=bpool

export USE_EXISTING_PART=yes
export EFI_PART=/dev/disk/by-id/nvme-eui.000000000000001000080d02003e9b51-part2
export ROOT_PART=/dev/disk/by-id/nvme-eui.000000000000001000080d02003e9b51-part7
export BOOT_PART=/dev/disk/by-id/nvme-eui.000000000000001000080d02003e9b51-part8
```

#### Using the entire drive

```shell
export ETHERNET=enp3s0
export NEW_HOSTNAME=rocinante
export YOURUSERNAME=hbarta
export ROOT_POOL_NAME=rpool
export BOOT_POOL_NAME=bpool

export USE_EXISTING_PART=no
export DRIVE_ID=nvme-eui.00000000
0000001000080d02003e9b51
```
`ls -l /dev/disk/by-id` will identify disks and partitions. `ip addr` will show the Ethernet device. (This process requires Ethernet.)

The file `env.sh` looks like a shell script but is intended to be copied/pasted into a terminal window. It is convenient to edit it to set the desired variables for the target system.

### Process
Boot the Debian Live USB. Note that to install using EFI it may be necessary to boot the USB using EFI.

1. Copy the scripts someplace convenient on the target system.
1. Run `initial.sh` to install ssh (so rest of the process can be run by ssh-ing in from another host.)
1. `sudo` to `root` user.
1. If installing to a disk partition (vs. the entire drive) the ZFS pool must be configured at or before this point.
1. Copy/paste `env.sh` to populate some environment variables. 
1. `sudo` to `root` and execute `install_Debian_to_ZFS_root.sh`. (Note: Until the debug mods near the end are reverted it is necessary to manually execute the `chroot` command.
1. Ponder the need for a post-install script and copy/paste commands form the linked instructions and enjoy!

## TODO

* Decide if I want the post-reboot script to install the desktop.
* Fully automate the script (Eliminate three interactive commands.)
