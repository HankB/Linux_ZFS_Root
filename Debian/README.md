# Debian ZFS Root

# Script fails at this time. Come back soon

Script to facilitate installing Debian Stretch on a ZFS root.

## Inspiration

[Debian Stretch Root on ZFS
](https://github.com/zfsonlinux/zfs/wiki/Debian-Stretch-Root-on-ZFS) as of [2019-04-18](https://github.com/zfsonlinux/zfs/wiki/Debian-Stretch-Root-on-ZFS/f8295f9368ee8f58ba2e626e38099fd71922f453
). Any references to "instructions" below refer to the contents of this link.

## Deviations from Debian Stretch Root on ZFS

The intent is to follow the instructions closely, however occasional problems cropped up that required further changes not included in the original instructions. 

* The script supports the capability to install dual boot with Windows or other Linux distros. It is entirely possible that it will not work with all distros. At present any problems encountered have resulted in failure to install and have not caused a problem with existing installations. Nevertheless is is highly recommended to back up the drive before proceeding. (I can backup a 120GB drive to my local file server in about 5 minutes.)
* The `-f` (force) flag is included in the `zpool create` commands because on too many occasions the command exited with a warning and indicated it could be overridden with this flag.
* The device is wiped using `wipefs` of all previous filesystem signatures. This was added because a previous ZFS pool would cause `zpool create` to fail, even with the `-f` option. In the case of using existing partitions, this is applied to the partitions selected for the `bpool` and `rpool`.

## Limitations
* The script requires interaction. Some commands could probably be fully automated but at present it is necessary to acknowledge a popup regarding the ZFS license. (Be careful entering the new root password as the script aborts on any errors.)
* No support to use existing ZFS pools. This is probably the next thing I will work on.
* The script requires interaction. Come commands could probably be fully automated but at present it is necessary to acknowledge a popup regarding the ZFS license. (Be careful entering the new root password as the script aborts on any errors.)

## Motivation

Provide a script to install Debian on ZFS side by side with Windows 10. Instructions describe how to do this using Debian for the whole disk. With appropriate modifications it can be performed with preconfigured partitions or ZFS pools.

Second... I have difficulty following detailed instructions. In the long run it is easier to script the process. It takes a little more time up front but can then be easily repeated when desired.

## Status

* Script has been updated to support the instructions as of 2019-04-18.
* Script now supports use of existing root and boot pools.

## WARNING WILL ROBINSON

**If something goes wrong this script *will* destroy any data on any target system drive.** I captured a full disk image backup before testing this on any of my systems. Taking a full image backup takes less time than reinstalling Windows should that be needed.

Needless to say, I am not responsible for any data loss incurred as a result of using this S/W. Use at your own risk and take appropriate precautions to backup your data.

### Other potential issues

This process does not decommission an existing MD RAID (See step 2.1) It will zap any existing partitions on the selected drive (if `$INSTALL_TYPE == "whole_disk"`)

If using an existing partition, it will create the pool on the indicated partition.

When using existing pools or partitions, it will not create or format the EFI partition. It is up to the user to create and format the EFI partition or point to one created by another install (e.g. Windows.)

Pools are created with `-o ashift=12`. For SSDs and perhaps even other drives `ashift=13` may be better. Edit the script to accomplish this.

Uses `tmpfs` for `/tmp`.

Uses simple host name - not FQDN (step 4.1)

`popularity-contest` (popularity contest) installed by default.

## Usage

### ENV variables

These determine how the install is processed. The most import one is INSTALL_TYPE which determines if the entire disk is formatted, existing partitions or existing pools are used. If this is wrong it could produce undesirable results. (`INSTALL_TYPE=whole_disk` will effectively wipe the disk)

Environment variables are provided to the script from a text file. If a text file is provided on the `install_Debian_to_ZFS_root.sh` command line, itr will be sourced in the script. If none is provided, the file `env.sh` will be used. The default behavior is the same as

```bash
install_Debian_to_ZFS_root.sh env.sh
```

Examples of settings are shown.

#### Using an existing partition (e.g. dual or multi-boot.)

```shell
export ETHERNET=enp3s0
export NEW_HOSTNAME=rocinante
export YOURUSERNAME=hbarta
export ROOT_POOL_NAME=rpool
export BOOT_POOL_NAME=bpool
export ENCRYPT=no|yes

export INSTALL_TYPE=use_partitions

export EFI_PART=/dev/disk/by-id/nvme-eui.000000000000001000080d02003e9b51-part2
export ROOT_PART=/dev/disk/by-id/nvme-eui.000000000000001000080d02003e9b51-part7
export BOOT_PART=/dev/disk/by-id/nvme-eui.000000000000001000080d02003e9b51-part8
```

It is the responsibility of the user to prepare all three partitions. In addition, it is required that the EFI partition be formatted. It can be an existing EFI partition from e.g. a Windows install or a new partition formatted as described in the instructions.

#### INSTALL_TYPE=whole_disk

```shell
export ETHERNET=enp3s0
export NEW_HOSTNAME=rocinante
export YOURUSERNAME=hbarta
export ROOT_POOL_NAME=rpool
export BOOT_POOL_NAME=bpool
export ENCRYPT=no|yes

export INSTALL_TYPE=whole_disk

export DRIVE_ID=nvme-eui.000000000000001000080d02003e9b51
```

The script will clear the drive, create and format all required partitions. This option requires the least preparation.

#### INSTALL_TYPE=use_pools

```shell
export ETHERNET=enp3s0
export NEW_HOSTNAME=rocinante
export YOURUSERNAME=hbarta
export ROOT_POOL_NAME=rpool
export BOOT_POOL_NAME=bpool
export ENCRYPT=no|yes

export INSTALL_TYPE=use_pools

export EFI_PART=/dev/disk/by-id/nvme-eui.000000000000001000080d02003e9b51-part2
```

This option requires that the EFI partition be present as for `INSTALL_TYPE=use_partitions`. In addition the root and boot pools must be created.


`ls -l /dev/disk/by-id` will identify disks and partitions. `ip addr` will show the Ethernet device. (This process requires Ethernet.) The partitions are conveniently created using `sgdisk` as shown in the instructions.

The file `env.sh` looks like a shell script but is intended to be copied/pasted into a terminal window. It is convenient to edit it to set the desired variables for the target system.

### Process

Boot the Debian Live USB. Note that to install using EFI it may be necessary to boot the USB using EFI.

1. Prepare any required partitions and/or pools as listed above.
1. Copy the scripts to a convenient directory in the live environment. (Or put on a handy USB drive.)
1. Run `initial.sh` to install `ssh` so rest of the process can be run by `ssh`-ing in from another host. (This can be skipped if all work is done at the console.)
1. Identify the required environment variables and edit `env.sh` accordingly.
1. `sudo` to `root` user.
1. Source `env.sh` to populate the environment variables.
1. Execute `install_Debian_to_ZFS_root.sh`.
1. Ponder the need for a post-install script and copy/paste commands from the linked instructions and enjoy!

## Contributing

I appreciate any help I can get. One down side to this project is that there is no unit testing. The only testing I have performed is to execute the script in whole to see if it works. Further testing would be fully appreciated.

My skills with shell scripting are adequate but less than many others. I appreciate suggestion for making the script more robust.

Feel free to submit pull requests for features or other improvements. My inclination is to accept them but I reserve the right to reject any that reduce the usefulness of this script for my purposes or otherwise seem unsuitable.

I have submitted issues for things that I anticipate as possible next steps. If you wish to help with one of these, please reply to the issue so we can coordinate efforts (before you start work.) If you see the need for something additional or identify a problem, please file an issue.

## TODO

* Fully automate the script (Eliminate three interactive commands.)
* ~~~Install to preconfigured ZFS pools.~~~
* ~~~Support encryption.~~~
