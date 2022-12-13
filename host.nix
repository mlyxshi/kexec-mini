{ config, pkgs, lib, ... }: {
  documentation.enable = false;
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  networking = {
    hostName = "systemd-stage1";
    usePredictableInterfaceNames = false;
  };

  system.stateVersion = lib.trivial.release;

  # need for sysroot
  fileSystems."/" = {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  boot.loader.grub.enable = false;
  boot.kernelParams = [
    "systemd.show_status=true"
    "systemd.log_level=info"
    "systemd.log_target=console"
    "systemd.journald.forward_to_console=1"
  ];
}
