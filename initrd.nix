{ config, pkgs, lib, ... }: {
  boot.initrd.environment.etc = {
    "hostname".text = "${config.networking.hostName}\n";
    "resolv.conf".text = "nameserver 1.1.1.1\n"; # TODO replace with systemd-resolved upstream
    "ssl/certs/ca-certificates.crt".source = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    "nix/nix.conf".text = ''
      build-users-group =
      extra-experimental-features = nix-command flakes
      # workaround https://github.com/NixOS/nix/issues/5076
      sandbox = false

      substituters = https://cache.nixos.org
      trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
    '';
    "group".text = ''
      root:x:0:
      nogroup:x:65534:
    '';

    "lf/lfrc".text = ''
      set hidden true
      set number true
      set drawbox true
      set dircounts true
      set incsearch true
      set period 1
      map Q   quit
      map D   delete
    '';
  };


  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.emergencyAccess = true;

  # This is the upstream expression, just with bashInteractive instead of bash.
  boot.initrd.systemd.initrdBin =
    let
      systemd = config.boot.initrd.systemd.package;
    in
    lib.mkForce ([ pkgs.bashInteractive pkgs.coreutils systemd.kmod systemd ] ++ [ pkgs.dosfstools pkgs.e2fsprogs ]);

  boot.initrd.systemd.storePaths = [
    "${pkgs.ncurses}/share/terminfo/"
    "${pkgs.bash}"
  ];

  boot.initrd.systemd.extraBin = {
    # nix & installer
    nix = "${pkgs.nixStatic}/bin/nix";
    nix-store = "${pkgs.nixStatic}/bin/nix-store";
    nix-env = "${pkgs.nixStatic}/bin/nix-env";
    busybox = "${pkgs.busybox-sandbox-shell}/bin/busybox";
    nixos-enter = "${pkgs.nixos-install-tools}/bin/nixos-enter";
    unshare = "${pkgs.util-linux}/bin/unshare";

    ssh-keygen = "${config.programs.ssh.package}/bin/ssh-keygen";
    setsid = "${pkgs.util-linux}/bin/setsid";

    # partitioning
    parted = "${pkgs.parted}/bin/parted";

    curl = "${pkgs.curl}/bin/curl";
    lf = "${pkgs.lf}/bin/lf";

    get-kernel-param = pkgs.writeScript "get-kernel-param" ''
      for o in $(< /proc/cmdline); do
          case $o in
              $1=*)
                  echo "''${o#"$1="}"
                  ;;
          esac
      done
    '';
  };


  # ssh
  boot.initrd.systemd.network.wait-online.anyInterface = true;
  boot.initrd.systemd.network.networks = { }; # dhcp
  boot.initrd.network.enable = true;
  boot.initrd.network.ssh.enable = true;
  boot.initrd.systemd.services.setup-ssh-authorized-keys = {
    requires = [ "initrd-fs.target" ];
    after = [ "initrd-fs.target" ];
    requiredBy = [ "sshd.service" ];
    before = [ "sshd.service" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /etc/ssh/authorized_keys.d
      param="$(get-kernel-param "ssh_authorized_key")"
      if [ -n "$param" ]; then
         umask 177
         (echo -e "\n"; echo "$param" | base64 -d) >> /etc/ssh/authorized_keys.d/root
         cat /etc/ssh/authorized_keys.d/root
         echo "Using ssh authorized key from kernel parameter"
      fi
    '';
  };

  boot.initrd.systemd.services.generate-ssh-host-key = {
    requires = [ "initrd-fs.target" ];
    after = [ "initrd-fs.target" ];
    requiredBy = [ "sshd.service" ];
    before = [ "sshd.service" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /etc/ssh/

      param="$(get-kernel-param "ssh_host_key")"
      if [ -n "$param" ]; then
         umask 177
         echo "$param" | base64 -d > /etc/ssh/ssh_host_ed25519_key
         ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub
         echo "Using ssh host key from kernel parameter"
      fi
      if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
         ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -t ed25519 -N ""
         echo "Generated new ssh host key"
      fi
    '';
  };


  # move everything in / to /sysroot and switch-root into
  # it. This runs a few things twice and wastes some memory
  # but is necessary for nix --store flag as pivot_root does
  # not work on rootfs.
  boot.initrd.systemd.services.remount-root = {
    requires = [ "systemd-udevd.service" "initrd-root-fs.target" ];
    after = [ "systemd-udevd.service" ];
    requiredBy = [ "initrd-fs.target" ];
    before = [ "initrd-fs.target" ];

    unitConfig.DefaultDependencies = false;
    serviceConfig.Type = "oneshot";
    script = ''
      root_fs_type="$(mount|awk '$3 == "/" { print $1 }')"
      if [ "$root_fs_type" != "tmpfs" ]; then
          cp -R /bin /etc  /init  /lib  /nix  /root  /sbin  /var /sysroot
          systemctl --no-block switch-root /sysroot /bin/init
      fi
    '';
  };


  # keep in stage 1
  boot.initrd.systemd.services.initrd-switch-root.enable = false;
  boot.initrd.systemd.services.initrd-cleanup.enable = false;
  boot.initrd.systemd.services.initrd-parse-etc.enable = false;



  # When these are enabled, they prevent useful output from going to the console
  boot.initrd.systemd.paths.systemd-ask-password-console.enable = false;
  boot.initrd.systemd.services.systemd-ask-password-console.enable = false;
}
