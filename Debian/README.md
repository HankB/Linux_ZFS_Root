# Debian ZFS Root

Script to facilitate installing Debian Bullseye on a ZFS root.

## Status

The world is moving to Debian Bullseye. So is this script. At present there are no instructions for installing on Bullseye so the script was modified based on the instructions for Buster and changes s/buster/bullseye/ made accordingly. In addition, the backports have been removed from the `apt` sources files. As of 2021-09-07 ZFS is not in  `bullseye-backports`. The slightly modified install seems to work fine for me. (One user has been having difficulty with `rpool` not imported at boot.)

As some users may wish to install Buster, the code as it stands has been branched as `buster` and will likely only see bugfixes if needed.

Complete:

* VM test using whole disk, no encryption (`testing/whole.std.no_enc.sh`)
* VM, real metal test using specified partitions, native encryption (`testing/part.std.zfs_enc.sh`)

## Note

Please see warnings.

Debian 11.0 Live Gnome install media is used for all testing and is recommended. (`debian-live-11.0.0-amd64-gnome.iso` from <https://cdimage.debian.org/mirror/cdimage/release/current-live/amd64/iso-hybrid/>)

Backports are no longer used as Bulklseye and backports on Buster both use 2.0.3-9 as of 2021-09-02.

## Inspiration

[Debian Buster Root on ZFS](https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Buster%20Root%20on%20ZFS.html)
Any references to "instructions" below refer to the contents of this link.

## Roadmap

At present two install scenarios have been tested. All require testing.

## Deviations from Debian Buster Root on ZFS

The intent is to follow the instructions closely, however occasional problems cropped up that required changes to the original instructions.

* Uses the Bullseye live media to install Bullseye.
* The script supports the capability to install dual boot with Windows or other Linux distros. It is entirely possible that it will not work with all distros. At present any problems encountered have resulted in failure to install and have not caused a problem with existing installations. Nevertheless is is highly recommended to back up the drive before proceeding. 
* The `-f` (force) flag is included in the `zpool create` commands because on too many occasions the command exited with a warning and indicated it could be overridden with this flag.
* The device is wiped using `wipefs` of all previous filesystem signatures. This was added because a previous ZFS pool would cause `zpool create` to fail, even with the `-f` option. In the case of using preconfigured partitions, this is applied to the partitions selected for the boot pool and root pool.
* Specify the URL http://deb.debian.org/debian on the `debootstrap` command line. It is not clear to me what the default is.
TODO: reciew all instructions to identify any other changes/deviations.

## Limitations

* The script requires interaction. Some commands could probably be fully automated but at present it is necessary to acknowledge a popup regarding the ZFS license. Be expecially careful when typing the pass phrase as if the two dont match, the install fails.

## Motivation

Provide a script to install Debian on ZFS side by side with Windows 10. Instructions describe how to do this using Debian for the whole disk. With appropriate modifications it can be performed with preconfigured partitions or ZFS pools which have been p[repared in advance].

Second... I have difficulty following detailed instructions. In the long run it is easier to script the process. It takes a little more time up front but can then be easily repeated when desired.

## Alternatives

There are other scripts that may suit your needs better than this.

* https://github.com/hn/debian-stretch-zfs-root
* https://github.com/hn/debian-buster-zfs-root
* https://github.com/saveriomiroddi/zfs-installer

## WARNING WILL ROBINSON

It may seem like a sensible thing to do to try to install to a drive from a normal system (as opposed to from a live environment booted from USB.) This has been tried and did not end well. (Second opportunity to roll back `bpool` and `rpool` today.)

**If something goes wrong this script *will* destroy any data on any target system drive.** I captured a full disk image backup before testing this on any of my systems. Taking a full image backup takes less time than reinstalling Windows should that be needed.

Needless to say, I am not responsible for any data loss incurred as a result of using this S/W. Use at your own risk and take appropriate precautions to backup your data.

### Other potential issues

This process does not decommission an existing MD RAID (See step 2.1) It will zap any existing partitions on the selected drive (if `$INSTALL_TYPE == "whole_disk"`)

If using existing partitions, it will create the pools on the indicated partitions. Two partition are required for pools and one for EFI.

When using existing pools or partitions, it will not create or format the EFI partition. It is up to the user to create and format the EFI partition or point to one created by another install (e.g. Windows.)

Pools are created with `-o ashift=12`. For SSDs and perhaps even other drives `ashift=13` may be better. Edit the script to accomplish this.

Uses `tmpfs` for `/tmp`.

Uses simple host name - not FQDN (step 4.1)

`popularity-contest` (popularity contest) installed by default.

## Usage

### Suggested

Pick a settings file from the `.../testing` directoy and tailor it to fit your specifics. Some commands in the settings files will prepare the test environment (and should not be included for normal usage) and others configure the environment variables used to perform the installation. Some day these will be clearly identified. See also the files in `.../testing/obsolete`. Run the script using that. If necessary,modify the script itself.

### ENV variables

These determine how the install is processed. The most import one is INSTALL_TYPE which determines if the entire disk is formatted, existing partitions or existing pools are used. If this is wrong it could produce undesirable results. (`INSTALL_TYPE=whole_disk` will effectively wipe the disk)

Environment variables are provided to the script from a text file. If a text file is provided on the `install_Debian_to_ZFS_root.sh` command line, it will be sourced in the script. If none is provided, the file `env.sh` will be used. The default behavior is the same as

```bash
install_Debian_to_ZFS_root.sh env.sh
```

Please see the test settings files to see what environment variables are used for the various cases.

Examples of settings are shown.

## Testing

Please see the README in testing.

In order to improve quality the script is now checked with the `shellcheck` script linter. The script run within the `chroot` has also been checked with `shellcheck` and produced several warnings. I spent an hour or two trying to fix those before deciding they were not so serious.

## Contributing

I appreciate any help I can get. One down side to this project is that there is no unit testing. The only testing I have performed is to execute the script in whole to see if it works. Further testing would be fully appreciated.

My skills with shell scripting are adequate but less than many others. I appreciate suggestion for making the script more robust.

Feel free to submit pull requests for features or other improvements. My inclination is to accept them but I reserve the right to reject any that reduce the usefulness of this script for my purposes or otherwise seem unsuitable.

I have submitted issues for things that I anticipate as possible next steps. If you wish to help with one of these, please reply to the issue so we can coordinate efforts (before you start work.) If you see the need for something additional or identify a problem, please file an issue.

## Errata

1. Many tests do not perform well resulting in a no rpool condition on reboot. Repeating the identical test often succeeded. Fiddling with rpool before booting sometimes helps. This has been seen on real H/W as well. A fixup was added at the end of the script which will report `root pool fixup applied` if needed and otherwise simply import and then export the pool. During testing the fixup was never seen. Final version during testing was zfs-2.0.3-9 and perhaps a fix was issued for this. ZFS version will be tracked more closely during subsequent testing.
1. When installing to preconfigured partitions and when using UEFI boot, it is assumed that the EFI partition exists and for that reason it will not be formatted by the script. This is done to support dual boot. For this reason if you create an empty EFI partition, it must be formatted before running the script or the script will fail.
