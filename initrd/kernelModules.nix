let
  qemu = [ "virtio_net" "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_scsi" "virtio_balloon" "virtio_console" ];
  hyperv = [ "hv_balloon" "hv_netvsc" "hv_storvsc" "hv_utils" "hv_vmbus" ];
  zram = [ "zram" ];
  # btrfs,vfat,efivarfs
  fileSystem = [ "btrfs" "crc32c" ]  ++ [ "vfat" "nls_cp437" "nls_iso8859-1" ] ++ [ "efivarfs" ]; 
  # add extra kernel modules: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/all-hardware.nix
  modules = qemu ++ hyperv ++ fileSystem ++ zram;
in
{
  boot.initrd.kernelModules = modules;
  # NixOS also include default kernel modules: https://github.com/NixOS/nixpkgs/blob/660e7737851506374da39c0fa550c202c824a17c/nixos/modules/system/boot/kernel.nix#L214
  # boot.initrd.includeDefaultModules = false;


  boot.extraModprobeConfig = ''
    options zram num_devices=1
  '';
}
