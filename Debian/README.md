# Debian ZFS Root

Script to facilitate installing Debian Stretch on a ZFS root.

## Inspiration

[Debian Stretch Root on ZFS
](https://github.com/zfsonlinux/zfs/wiki/Debian-Stretch-Root-on-ZFS) as of 2018-10-09.

## Motivation

Provide a script to install Debian on ZFS side by side with Windows 10. Instructions in the link above describe how to do this using Debian for the whole disk.

## Status

Started migrating script produced to install Ubuntu.

Note: As of Rickard Laager's email to zfs-discuss@list.zfsonlinux.org on Mar 18, 2019, 10:57 PM this script is no longer synchronized with the instructions referenced above. The script may still work (It did for me) but will not utilize the most recent improvements in the procedure.

## WARNING WILL ROBINSON

**If something goes wrong this script *will* destroy any data on any target system drive.** I captured a full disk image backup before testing this on any of my systems. Taking a full image backup takes less time than reinstalling Windows should that be needed.

Needless to say, I am not responsible for any data loss incurred as a result of using this S/W. Ise at your own risk and take appropriate precautions to backup your data.

## Usage

### ENV variables

These determine how the install is processed. The most import one is USE_EXISTING_PART which determines if the entire disk is formatted as a ZFS pool or if an existing partition
is to be used. Getting this wrong could destroy existing data on the drive. Two examples of settings are shown.

#### Using an existing partition (e.g. dual or multi-boot.)
```shell
export USE_EXISTING_PART=yes
export EFI_PART=/dev/disk/by-id/nvme-eui.000000000000001000080d02003e9b51-part2
export ROOT_PART=/dev/disk/by-id/nvme-eui.000000000000001000080d02003e9b51-part7
export ETHERNET=enp3s0
export NEW_HOSTNAME=rocinante
export YOURUSERNAME=hbarta
```

#### Using the entire drive.

```shell
export USE_EXISTING_PART=no
export DRIVE_ID=nvme-eui.000000000000001000080d02003e9b51
export ETHERNET=enp3s0
export NEW_HOSTNAME=rocinante
export YOURUSERNAME=hbarta
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
