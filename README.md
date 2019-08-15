# Linux_ZFS_Root

Commands/script to install Linux on ZFS root. There are presently two variants, one that installs Ubuntu and the other, Debian Stretch. Please see the README in .../Ubuntu and .../Debian for further details.

## Status

### Ubuntu

Ubuntu branch is virtually abandoned. Canonical is pursuing support of ZFS on root for the desktop so it seems that effort is better spent on the Debian branch which seems less likely to get that from Debian.

### Debian

Debian is under active development. The script has been updated to support Buster and with backports. (Backports provide 0.7.13 while the regular repos include 0.7.12.) Work is complete but not fully tested on including 0.8.1 directly from the ZoL Github repo.
