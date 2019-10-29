# Testing

## My Procedure

Initial testing was performed on real hardware. As more options were added the need for additional testing became apparent and further testing has been performed on a VM. To facilitate this testing, I have expanded the `env.sh` script in some cases to prepare partitions and filesystems to more fully automate the test.

The test settings files may also provide a useful starting point tro customize a real installation, preparing partitions, filesystems and pools as desired.

My procedure is as follows.

1) Determine how to get the VM to boot the install ISO in EFI mode. For Virtualbox this required

* ticking the "Enable EFI (special OSes only)" box in Settings -> System -> Motherboard
* mounting the Live ISO on the SATA bus in Settings -> Storage. (Linux is a special OS! ;) )
* Configure Networking - Settings -> Network -> Attached to: Bridged Adapter. (Allows the host to connect with the guest.) (Fairly early on I switched to using NAT for the network connection and initiating file transfers from the guest)

2) Boot from the ISO and confirm that the system booted in EFI mode. Check for existence of `/sys/firmware/efi`. (Shutdown the VM and clone from it for all subsequent tests.)
0) Once in the live environment, install and start `openssh-server`. (Not needed when initiating the connection from the guest.)

```shell
sudo -s
apt update
apt install openssh-server
systemctl start openssh-server
```

4) `sftp` to from host to guest and copy the files needed to perform the test (`install_Debian_to_ZFS_root.sh` and `env.sh` or whatever the settings file is named.)
0) `ssh` from host to guest to complete the installation.
0) Modify the settings file to match the Ethernet device name and SATA disk ID. The Ethernet device name seems stable but the SATA disk ID changes each time I clone the VM.
0) Run the test using the command `./install_Debian_to_ZFS_root.sh <settings file>`.
0) Monitor the process and respond to any requests for further information.
0) When the installation has completed successfully, there will be no indication of errors in the terminal. At that point reboot and confirm that the system comes up. I check that both pools exist and are imported and that `/boot/efi` has contents. I'm not aware that any further testing is needed.

There are times when the reboot goes to an EFI menu rather than the GRUB menu. In that case I find it is necessary to type `FS0:\EFI\debian\grubx64.efi` which then loads the GRUB menu. (The EFI shell supports TAB completion so it is only necessary to type `FS0:\<tab>\<tab>\<tab><enter>`)

## Files

This directory contains the settings files I have used for the various tests. They also may need to be tailored for the drive ID.
Files for previous versions of the script which are no longar applicable (but may be otherwise interesting) are in `.../obsolete`.

## Recording test results

At present I have a [Google Sheet](https://docs.google.com/spreadsheets/d/1aqDocC9FZhQqJpilyDI7LxOcShHNU8znhwk0IFEm-gQ/edit?usp=sharing) with a grid for possible combinations. My intent is to add a sheet for any commit that requires testing. (At present the grid does not include any testing for dual boot systems.)
With the most recent update, a new sheet has been created. (https://docs.google.com/spreadsheets/d/1F_enjjrheYRwfxnIVbyzsWkdxQesY6dfqt8ElmtgOL8/edit?usp=sharing)

I have also entered an issue for testing and tagged it as "help wanted." I have recorded the first batch of tests but that does not seem like a good long term plan.

## Contributing

Please feel free to suggest improvements in the realm of testing. Things I could particularly use help with include

1) Configuration for using libvirt/KVM. I tried it and was not able to figure out how to use it.
2) Suggest a way to run tests on a headless system.
