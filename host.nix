{ config, pkgs, lib, ... }: {
  documentation.enable = false;
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  networking = {
    hostName = "systemd-stage1";
    usePredictableInterfaceNames = false;
  };

  system.stateVersion = lib.trivial.release;

  # toplevel does not build without a root fs but is useful for debugging and it does not seem to hurt
  fileSystems."/" = {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
    neededForBoot = true;
  };

  boot.loader.grub.enable = false;
  boot.kernelParams = [
    "systemd.show_status=true"
    "systemd.log_level=info"
    "systemd.log_target=console"
    "systemd.journald.forward_to_console=1"
  ];
}
