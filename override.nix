# personal usage
{pkgs, lib, config, modulesPath, ...}:{

  boot.initrd.kernelModules = [ "virtio_net" "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_scsi" "virtio_balloon" "virtio_console" ];

  boot.initrd.systemd.extraBin = {
    curl = "${pkgs.curl}/bin/curl";
  };

  boot.initrd.systemd.services.auto-install.script = lib.mkForce ''
    # systemd.services.<name>.script will automatically set -e
    # If we don't set +e, the script will exit on the first error
    # nixos-enter --root /mnt -- /run/current-system/sw/bin/bootctl install
    # nixos-enter --root /mnt -- /run/current-system/bin/switch-to-configuration boot
    # will fail with error code 1, However, these errors are acceptable.(Not Functional Errors)
      
    set +e
          
    host=$(get-kernel-param host)
    if [ -n "$host" ]
    then
      echo $host
    else
      echo "No flake url defined for auto-installer"
      exit 1
    fi

    tg_id=$(get-kernel-param tg_id)
    tg_token=$(get-kernel-param tg_token)
    age_key=$(get-kernel-param age_key)

    parted --script /dev/sda \
    mklabel gpt \
    mkpart "BOOT" fat32  1MiB  512MiB \
    mkpart "NIXOS" ext4 512MiB 100% \
    set 1 esp on 

    mkfs.fat -F32 /dev/sda1
    mkfs.ext4 -F /dev/sda2 

    mkdir -p /mnt
    mount /dev/sda2 /mnt
    mkdir -p /mnt/boot
    mount /dev/sda1 /mnt/boot
    mkdir -p /mnt/var/lib/age/ 

    [[ -n "$age_key" ]] && curl -sLo /mnt/var/lib/age/sshkey $age_key

    mkdir -p /mnt/{etc,tmp} && touch /mnt/etc/NIXOS
    nix build  --store /mnt --profile /mnt/nix/var/nix/profiles/system  github:mlyxshi/flake#nixosConfigurations.$host.config.system.build.toplevel \
    --extra-trusted-public-keys "cache.mlyxshi.com:qbWevQEhY/rV6wa21Jaivh+Lw2AArTFwCB2J6ll4xOI=" \
    --extra-substituters "http://cache.mlyxshi.com" -v

    nixos-enter --root /mnt -- /run/current-system/sw/bin/bootctl install
    nixos-enter --root /mnt -- /run/current-system/bin/switch-to-configuration boot

    [[ -n "$tg_id" && -n "$tg_token" ]] && curl -s -X POST https://api.telegram.org/bot$tg_token/sendMessage -d chat_id=$tg_id -d text="NixOS installed successfully on $host"
        
    for i in /etc/ssh/ssh_host_*; do cp $i /mnt/etc/ssh; done
    reboot
  '';
}
