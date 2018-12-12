# Ubuntu ZFS Root

Script to facilitate installing Ubuntu on a ZFS root.

## Inspiration

[Ubuntu 18.04 Root on ZFS
](https://github.com/zfsonlinux/zfs/wiki/Ubuntu-18.04-Root-on-ZFS) as of 2018-11-16.

## Motivation

Provide a script to install Ubuntu on ZFS side by side with Windows 10. Instructions in the link above describe how to do this using Ubuntu for the whole disk.

## Status

Nearing completion to install Ubuntu whole disk.

The main script has sort of been run through (though the chroot script execution is commented out and needs to be run manually. But I'm eager to get on with dual boot installation.

## Usage

Boot the USB and

1. Copy the scripts someplace convenient on the target system.
1. Run `initial.sh` to install ssh (so rest of the process can be run by ssh-ing in from anopther host.)
1. Copy/paste `env.sh` to populate some environment variables. (`ls -l /dev/disk/by-id` will identify disks and `ip addr` will reveal the Ethernet device. (This setup assumes there will be Ethernet.)
1. `sudo` to `root` and execute `install_Ubuntu_to_ZFS_root.sh`. (Note: Until the debug mods near the end are reverted it is necessary to manually execute the `chroot` command.
1. Ponder the need for a post-install script and copy/paste commands form the linked instructions and enjoy!

## TODO

Modify to install side by side with Windows (or possibly some other OS.)