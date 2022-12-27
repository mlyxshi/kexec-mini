# Intro
Based on [dep-sys/nix-dabei](https://github.com/dep-sys/nix-dabei/)

Modified for personal usage

Only support btrfs and vfat
```
remount-root.service  [ switch-root is required, because nix --store do not support rootfs ]
    |
    v
initrd-fs.target
    |
    v
auto-install.service
    |
    v
initrd.target(default)

```

[Hydra](https://hydra.mlyxshi.com/jobset/kexec/build) 
# Usage
### From running linux distro
```
curl -sL https://hydra.mlyxshi.com/job/kexec/build/$(uname -m)/latest/download-by-type/file/kexec | bash -s
```
### From netboot.xyz ipxe(Rescue)

```sh
# UEFI Shell
FS0:
ifconfig -s eth0 dhcp
tftp 138.2.16.45 netboot.xyz.efi
tftp 138.2.16.45 netboot.xyz-arm64.efi
exit
```
```
# Format: cat YOUR_KEY | base64 -w0
set cmdline ssh_authorized_key=c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU1wYVkzTHlDVzRISHFicDRTQTR0bkErMUJrZ3dydHJvMnMvREVzQmNQRGUKCg==
``` 
```
chain https://hydra.mlyxshi.com/job/kexec/build/x86-64/latest/download-by-type/file/ipxe
```
```
chain https://hydra.mlyxshi.com/job/kexec/build/aarch64/latest/download-by-type/file/ipxe
```
# Test
```
nix run -L .#
```