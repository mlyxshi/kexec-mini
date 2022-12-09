# personal usage
{ pkgs, lib, config, ... }:
let
  installScript = ''
    host=$(get-kernel-param host)
    if [ -n "$host" ]
    then
      echo $host
    else
      echo "No host defined for auto-installer"
      exit 1
    fi

    tg_id=$(get-kernel-param tg_id)
    tg_token=$(get-kernel-param tg_token)
    age_key=$(get-kernel-param age_key)
    local_test=$(get-kernel-param local_test)
    [[ $locol_test -eq 1 ]] && local || cloud

    cloud(){
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
    }   

    local(){
      parted --script /dev/vda \
      mklabel gpt \
      mkpart "BOOT" fat32  1MiB  512MiB \
      mkpart "NIXOS" ext4 512MiB 100% \
      set 1 esp on 

      mkfs.fat -F32 /dev/vda1
      mkfs.ext4 -F /dev/vda2 

      mkdir -p /mnt
      mount /dev/vda2 /mnt
      mkdir -p /mnt/boot
      mount /dev/vda1 /mnt/boot  
    }  

    # support UEFI systemd-boot
    mount -t efivarfs efivarfs /sys/firmware/efi/efivars

    mkdir -p /mnt/var/lib/age/ 
    [[ -n "$age_key" ]] && curl -sLo /mnt/var/lib/age/sshkey $age_key

    mkdir -p /mnt/{etc,tmp} && touch /mnt/etc/NIXOS
    nix build  --store /mnt --profile /mnt/nix/var/nix/profiles/system  github:mlyxshi/flake#nixosConfigurations.$host.config.system.build.toplevel \
    --extra-trusted-public-keys "cache.mlyxshi.com:qbWevQEhY/rV6wa21Jaivh+Lw2AArTFwCB2J6ll4xOI=" \
    --extra-substituters "http://cache.mlyxshi.com" -v

    NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- /run/current-system/bin/switch-to-configuration boot

    [[ -n "$tg_id" && -n "$tg_token" ]] && curl -s -X POST https://api.telegram.org/bot$tg_token/sendMessage -d chat_id=$tg_id -d text="NixOS installed successfully on $host"
        
    for i in /etc/ssh/ssh_host_ed25519_key*; do cp $i /mnt/etc/ssh; done
    reboot
  '';
in
{
  boot.initrd.systemd.services = {
    auto-install = {
      requires = [ "initrd-fs.target" "systemd-udevd.service" "network-online.target" ];
      after = [ "initrd-fs.target" "systemd-udevd.service" "network-online.target" ];
      requiredBy = [ "initrd.target" ];
      before = [ "initrd.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig.Type = "oneshot";
      script = installScript;
    };
  };
}
