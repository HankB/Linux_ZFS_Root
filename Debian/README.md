# Debian ZFS Root

Script to facilitate installing Debian Buster on a ZFS root.

# Note

<<<<<<< HEAD
Please see warnings.

Debian 10.1 Live Gnome install media is used for all testing and is recommended.

This commit has been fairly thoroughly tested including on real H/W with the latest release available in backports (0.8.2-2~bpo10+1).

As of 2019-09-21 the instructions no longer support the EXPERIMENTAL branch and have been simplified to use backports for all installs. LUKS encryption was removed and has since been restored.

## Inspiration

[Debian Buster Root on ZFS](https://github.com/zfsonlinux/zfs/wiki/Debian-Buster-Root-on-ZFS)
Any references to "instructions" below refer to the contents of this links.

## Roadmap

The intent of this script is to automate the instructions linked above. Alternate pool configurations (e.g. RAIDZ5, mirror etc.) are left to the user mto prepare and the script can be used to install to them. At present all functionality passes the tests listed at [Google Sheets](https://docs.google.com/spreadsheets/d/1F_enjjrheYRwfxnIVbyzsWkdxQesY6dfqt8ElmtgOL8/edit?usp=sharing) for commit 9e27688 and using Debian Live 10.1. 

The need for testing can come from several external sources.

* Bug reports, pull requests and/or feature requests.
* Upgrade of backports to a new version of ZFS.
* Changes to the isntructions.

When the script changes to accommodate either of these, all tests are repeated.

## Deviations from Debian Buster Root on ZFS

The intent is to follow the instructions closely, however occasional problems cropped up that required changes to the original instructions.

* The script supports the capability to install dual boot with Windows or other Linux distros. It is entirely possible that it will not work with all distros. At present any problems encountered have resulted in failure to install and have not caused a problem with existing installations. Nevertheless is is highly recommended to back up the drive before proceeding. 
* The `-f` (force) flag is included in the `zpool create` commands because on too many occasions the command exited with a warning and indicated it could be overridden with this flag.
* The device is wiped using `wipefs` of all previous filesystem signatures. This was added because a previous ZFS pool would cause `zpool create` to fail, even with the `-f` option. In the case of using preconfigured partitions, this is applied to the partitions selected for the boot pool and root pool.
* Specify the URL http://deb.debian.org/debian on the `debootstrap` command line. It is not clear to me what the default is.

## Limitations

* UEFI support only. All of my PCs on which I would use this support UEFI and I have found advantages to using that. In the case of dual boot support it can use the existing UEFI partition or a diffewrent UEFI partition can be created and used.
* The script requires interaction. Some commands could probably be fully automated but at present it is necessary to acknowledge a popup regarding the ZFS license.

## Motivation

Provide a script to install Debian on ZFS side by side with Windows 10. Instructions describe how to do this using Debian for the whole disk. With appropriate modifications it can be performed with preconfigured partitions or ZFS pools.

Second... I have difficulty following detailed instructions. In the long run it is easier to script the process. It takes a little more time up front but can then be easily repeated when desired.

## Alternatives

There are other scripts that may suit your needs better than this.

* https://github.com/hn/debian-stretch-zfs-root
* https://github.com/hn/debian-buster-zfs-root
* https://github.com/saveriomiroddi/zfs-installer

## Status

At present (2021-03-12) Status is not current. Work is in progress to 

1. Update to current instructions.
1. Add support to install using BIOS/MBR boot (It turns out that my servers are ancient but still workable and do not support UEFI boot.)

Some cursory testing has been performed on a VM. No testing yet on real metal.

* Script has been checked with `shellcheck` and all reported issues resolved.
* Script is current with the intructions listed at https://github.com/zfsonlinux/zfs/wiki/Debian-Buster-Root-on-ZFS except for the `sources.list` additions.
* All test cases have passed using Debian Live 10.1. (see Errata)
* Testing scripts have been revised and all pass `shellcheck`.

## WARNING WILL ROBINSON

It may seem like a sensible thing to do to try to install to a drive from a normal system (as opposed to from a live boot environment.) It is not and it may make your existing system unbootable. (Second opportunity to roll back `bpool` and `rpool` today.)

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

Pick a settings file from the `.../testing` directoy and tailor it to fit your specifics. See also the files in `.../testing/obsolete`. Run the script using that. If necessary,modify the script itself.

### ENV variables

These determine how the install is processed. The most import one is INSTALL_TYPE which determines if the entire disk is formatted, existing partitions or existing pools are used. If this is wrong it could produce undesirable results. (`INSTALL_TYPE=whole_disk` will effectively wipe the disk)

Environment variables are provided to the script from a text file. If a text file is provided on the `install_Debian_to_ZFS_root.sh` command line, it will be sourced in the script. If none is provided, the file `env.sh` will be used. The default behavior is the same as

```bash
install_Debian_to_ZFS_root.sh env.sh
```

It would probably be betrter to describe these files as configuration files. Early on, the script did get these variables from the environment but that was early in development.

Please see the test settings files to see what environment variables are used for the various cases.

Examples of settings are shown.

## Testing

Please see the README in testing.

In order to improve quality the script is now checked with the `shellcheck` script linter.

## Contributing

I appreciate any help I can get. One down side to this project is that there is no unit testing. The only testing I have performed is to execute the script in whole to see if it works. Further testing would be fully appreciated.

My skills with shell scripting are adequate but less than many others. I appreciate suggestion for making the script more robust.

Feel free to submit pull requests for features or other improvements. My inclination is to accept them but I reserve the right to reject any that reduce the usefulness of this script for my purposes or otherwise seem unsuitable.

I have submitted issues for things that I anticipate as possible next steps. If you wish to help with one of these, please reply to the issue so we can coordinate efforts (before you start work.) If you see the need for something additional or identify a problem, please file an issue.

## Errata

1. Many tests do not perform well resulting in a no rpool condition on reboot. Repeating the identical test often succeeded. Fiddling with rpool before booting sometimes helps. This has been seen on real H/W as well. A fixup was added at the end of the script which will report `root pool fixup applied` if needed and otherwise simply import and then export the pool. During testing the fixup was never seen. Final version during testing was 0.8.2-2~bpo10+1 and perhaps a fix was issued for this. ZFS version will be tracked more closely during subsequent testing.
1. When installing to preconfigured partitions and when using UEFI boot, it is assumed that the EFI partition exists and for that reason it will noe be formatted by the script. This is done this way to support dual boot. For this reason if you create an empty EFI partition, it must be formatted before running the script or the script will fail.
