# Ubuntu ZFS Root

Script to facilitate installing Ubuntu on a ZFS root.

## Warning

This script is outdated as it does not include the separation of the boot pool (bpool) that the 
instructions on Github now specify. With Canonical working toward including ZFS in their installer, 
it seems not to make sense to put further work into this script and instead focus on the Debian variant.

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

## Operation

This script performs the same steps described in the link in "Inspiration." The major difference is that it can install to a partition that is already formatted as ZFS.

The details for a given installation are specified using environment variables. Please see `env.sh` to see what is needed.

## Usage

Boot the USB and

1. Copy the scripts someplace convenient on the target system.
1. If using an existing ZFS partition (required for dual boot configurations) create the zpool that will be used. (The script will create the filesystems on this pool.)
1. Run `initial.sh` to install ssh (so rest of the process can be run by ssh-ing in from another host.)
1. Modify `env.sh` to configure environment variables. (`ls -l /dev/disk/by-id` will identify disks and `ip addr` will reveal the Ethernet device. (This setup assumes there will be Ethernet.) env.sh is not normally executed but rather the exports are copied and pasted into the terminal window.
1. `sudo` to `root` and set the environment variables used by the install script.
1. execute `install_Ubuntu_to_ZFS_root.sh`.
1. Ponder the need for a post-install script and copy/paste commands from the linked instructions and enjoy!

## TODO

* Decide if I want the post-reboot script to install the desktop.
* Fully automate the script (Eliminate three interactive commands.)
