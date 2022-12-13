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
```
curl -sL https://github.com/mlyxshi/kexec-mini/releases/download/latest/kexec-$(uname -m) | bash -s
```
# Test
```
nix run -L .#
```