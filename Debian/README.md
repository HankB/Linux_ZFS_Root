# Debian ZFS Root

Script to facilitate installing Debian Stretch on a ZFS root.

## Inspiration

[Debian Stretch Root on ZFS
](https://github.com/zfsonlinux/zfs/wiki/Debian-Stretch-Root-on-ZFS) as of 2019-04-18.

## Deviations from Debian Stretch Root on ZFS

The intent is to follow the instructions closely, however occasional problems cropped up that required further changes not included in the original instructions. 

* The script supports the capability to install dual boot with Windows or other Linux distros. It is entirely possible that it will not work with all distros. At present any problems encountered have resulted in failure to install and have not caused a problem with existing installations. Nevertheless is is highly recommended to back up the drive before proceeding. (I can backup a 120GB drive to my local file server in about 5 minutes.)
* The `-f` (force) flag is included in the `zpool create` commands because on too many occasions the command exited with a warning and indicated it coiuld be overridden with this flag.
* The device is wiped using `wipefs` of all previous filesystem signatures. This was added because a previous ZFS pool would cause `zpool create` to fail, even with the `-f` option. In the case of usiung existing partitions, this is applied to the partitions selected for the `bpool` and `rpool`.

## Limitations

* UEFI support only. All of my PCs on which I would use this support UEFI and I have found advantages to using that. In the case of dual boot support it will use the existing UEFI partition.
* No support for encryption. Yet.
* No support to use existing ZFS pools. This is probably the next thing I will work on.
* The script requires interaction. Come commands could probably be fully automated but at present it is necessary to acknowledge a popup regarding the ZFS license. (Be careful entering the new root password as the script aborts on any errors.)

## Motivation

Provide a script to install Debian on ZFS side by side with Windows 10. Instructions in the link above describe how to do this using Debian for the whole disk. With appropriate modifications it can be performed with preconfigured partitions.

Second... I have difficulty following detailed instructions. In the long run it is easier to script the instructions. It takes a little more time up front but can then be easily repeated when desired.

## Status

Script has been updated to support the instructions as of 2019-04-18.

## WARNING WILL ROBINSON

**If something goes wrong this script *will* destroy any data on any target system drive.** I captured a full disk image backup before testing this on any of my systems. Taking a full image backup takes less time than reinstalling Windows should that be needed.

Needless to say, I am not responsible for any data loss incurred as a result of using this S/W. Use at your own risk and take appropriate precautions to backup your data.

### Other potential issues

This process does not decommission an existing MD RAID (See step 2.1) It will zap any existing partitions on the selected drive (if `$USE_EXISTING_PART == "no"`)

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
export DRIVE_ID=nvme-eui.000000000000001000080d02003e9b51
```

`ls -l /dev/disk/by-id` will identify disks and partitions. `ip addr` will show the Ethernet device. (This process requires Ethernet.)

The file `env.sh` looks like a shell script but is intended to be copied/pasted into a terminal window. It is convenient to edit it to set the desired variables for the target system.

### Process

Boot the Debian Live USB. Note that to install using EFI it may be necessary to boot the USB using EFI.

1. Copy the scripts to a convenient in the live environment.
1. Run `initial.sh` to install ssh (so rest of the process can be run by ssh-ing in from another host.)
1. Identify the required environment variables and edit `env.sh` accordingly.
1. `sudo` to `root` user.
1. Source `env.sh` to populate the environment variables.
1. Execute `install_Debian_to_ZFS_root.sh`.
1. Ponder the need for a post-install script and copy/paste commands from the linked instructions and enjoy!

## Contributing

I appreciate any help I can get. One down side to this project is that there is no unit testing. The only testing I have performed is to execute the script to see if it works. Further testing would be fully appreciated.

My skills with shell scripting are adequate. I appreciate suggestion for making the script more robust.

Feel free to submit pull requests for features or other improvements. My inclination is to accept them but I reserve the right to reject any that reduce the usefulness of this script for my purposes or otherwise seem unsuitable.

## TODO

* Fully automate the script (Eliminate three interactive commands.)
* Install to preconfigured ZFS pools.
* Support encryption.
