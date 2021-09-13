# Linux_ZFS_Root

Commands/script to install Linux on ZFS root. There are presently two variants, one that installs Ubuntu and the other, Debian Bullseye (or Buster). Please see the README in .../Ubuntu and .../Debian for further details.

## Status

### Ubuntu

Ubuntu branch is virtually abandoned. Canonical is pursuing support of ZFS on root for the desktop so it seems that effort is better spent on the Debian branch which seems less likely to get that from Debian.

### Debian

Debian is under active development. The script has been updated to support Bullseye and use backports for Buster. (As of 2021-09-07 backports provide zfs-2.0.3-9~bpo10+1 on Buster and zfs-2.0.3-9 is available in the normal repos on Bullseye.  
