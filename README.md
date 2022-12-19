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
# Usage
### From running linux distro
```
curl -sL https://github.com/mlyxshi/kexec-mini/releases/download/latest/kexec-$(uname -m) | bash -s
```
### From netboot.xyz ipxe(Rescue)

```sh
# UEFI Shell
FS0:
ifconfig -s eth0 dhcp
tftp 138.2.16.45 netboot.xyz.efi netboot.xyz.efi
tftp 138.2.16.45 netboot.xyz-arm64.efi netboot.xyz-arm64.efi
```
```
chain https://github.com/mlyxshi/kexec-mini/releases/download/latest/ipxe-x86_64 
```
```
chain https://github.com/mlyxshi/kexec-mini/releases/download/latest/ipxe-aarch64 
```
# Test
```
nix run -L .#
```