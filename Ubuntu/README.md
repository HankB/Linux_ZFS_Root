# Ubuntu ZFS Root

Script to facilitate installing Ubuntu on a ZFS root.

## Inspiration

[Ubuntu 18.04 Root on ZFS
](https://github.com/zfsonlinux/zfs/wiki/Ubuntu-18.04-Root-on-ZFS) as of 2018-11-16.

## Motivation

Provide a script to install Ubuntu on ZFS side by side with Windows 10. Instructions in the link above describe how to do this using Ubuntu for the whole disk.

## Status

Cursory testing to install dual boot with Windows is successful.

## WARNING WILL ROBINSON

**If something goes wrong this script *will* destroy any data on any target system drive.** I captured a full disk image backup before testing this on any of my systems. Taking a full image backup takes less time than reinstalling Windows should that be needed.

Needless to say, I am not responsible for any data loss incurred as a result of using this S/W. Ise at your own risk and take appropriate precautions to backup your data.

## Usage

Boot the USB and

1. Copy the scripts someplace convenient on the target system.
1. Run `initial.sh` to install ssh (so rest of the process can be run by ssh-ing in from anopther host.)
1. Copy/paste `env.sh` to populate some environment variables. (`ls -l /dev/disk/by-id` will identify disks and `ip addr` will reveal the Ethernet device. (This setup assumes there will be Ethernet.)
1. `sudo` to `root` and execute `install_Ubuntu_to_ZFS_root.sh`. (Note: Until the debug mods near the end are reverted it is necessary to manually execute the `chroot` command.
1. Ponder the need for a post-install script and copy/paste commands form the linked instructions and enjoy!

## TODO

* Decide if I want the post-reboot script to install the desktop.
* Fully automate the script (Eliminate three interactive commands.)