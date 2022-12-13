# This is only for testing [nix build] and [switch-to-configuration boot] functionality
# It actually can not boot
{ lib, ... }: {
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  system.stateVersion = lib.trivial.release;
  documentation.enable = false;

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-partlabel/BOOT";
      fsType = "vfat";
    };
    "/" = {
      fsType = "tmpfs";
      options = [ "mode=755" ];
    };
    "/nix"={
      device = "/dev/disk/by-partlabel/NIXOS";
      fsType = "btrfs";
      options = [ "subvol=nix" "noatime" "compress-force=zstd" ];
    };
    "/persist" = {
      device = "/dev/disk/by-partlabel/NIXOS";
      fsType = "btrfs";
      options = [ "subvol=persist" "noatime" "compress-force=zstd" ];
      # neededForBoot = true;
    };
  };
  boot.initrd.systemd.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
