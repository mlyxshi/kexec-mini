# Intro
Based on [dep-sys/nix-dabei](https://github.com/dep-sys/nix-dabei/)

Modified for personal usage

Only support ext4 and vfat
# Usage
```
curl -sL https://github.com/mlyxshi/kexec-mini/releases/download/latest/kexec-$(uname -m) | bash -s
```
# Test
```
nix run -L .#nixosConfigurations.kexec-x86_64.config.system.build.test
```