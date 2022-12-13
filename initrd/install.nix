# personal usage
{ pkgs, lib, config, ... }:
let
  installScript = ''
    flake_url=$(get-kernel-param flake_url)
    if [ -n "$flake_url" ]
    then
      echo $flake_url
    else
      echo "No flake_url defined for auto-installer"
      exit 1
    fi

    tg_id=$(get-kernel-param tg_id)
    tg_token=$(get-kernel-param tg_token)
    age_key=$(get-kernel-param age_key)
    local_test=$(get-kernel-param local_test)

    parted --script /dev/sda \
    mklabel gpt \
    mkpart "BOOT"  fat32  1MiB    512MiB \
    mkpart "NIXOS" btrfs  512MiB  100% \
    set 1 esp on 

    sleep 2

    NIXOS=/dev/disk/by-partlabel/NIXOS
    mkfs.fat -F 32 /dev/disk/by-partlabel/BOOT
    mkfs.btrfs -f $NIXOS

    mkdir -p /fsroot
    mount $NIXOS /fsroot
    btrfs subvol create /fsroot/nix
    btrfs subvol create /fsroot/persist

    mkdir -p /mnt/{boot,nix,persist}
    mount /dev/disk/by-partlabel/BOOT /mnt/boot
    mount -o subvol=nix,compress-force=zstd    $NIXOS /mnt/nix
    mount -o subvol=persist,compress-force=zstd $NIXOS /mnt/persist
    
    # support UEFI systemd-boot
    mount -t efivarfs efivarfs /sys/firmware/efi/efivars

    mkdir -p /mnt/var/lib/age/ 
    [[ -n "$age_key" ]] && curl -sLo /mnt/var/lib/age/sshkey $age_key

    mkdir -p /mnt/{etc,tmp} && touch /mnt/etc/NIXOS
    nix build  --store /mnt --profile /mnt/nix/var/nix/profiles/system  $flake_url.config.system.build.toplevel \
    --extra-trusted-public-keys "cache.mlyxshi.com:qbWevQEhY/rV6wa21Jaivh+Lw2AArTFwCB2J6ll4xOI=" \
    --extra-substituters "http://cache.mlyxshi.com" -v

    NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- /run/current-system/bin/switch-to-configuration boot

    [[ -n "$tg_id" && -n "$tg_token" ]] && curl -s -X POST https://api.telegram.org/bot$tg_token/sendMessage -d chat_id=$tg_id -d parse_mode=html -d text="<b>Install NixOS Completed</b>%0A$flake_url"
        
    for i in /etc/ssh/ssh_host_ed25519_key*; do cp $i /mnt/etc/ssh; done
    
    # in local test, we force exit 1 and use emergency shell to debug
    [[ -n "$local_test" ]] && exit 1 || reboot
  '';
in
{
  boot.initrd.systemd.services.auto-install = {
    requires = [ "network-online.target" ];
    after = [ "initrd-fs.target" "network-online.target" ];
    before = [ "initrd.target" ];
    serviceConfig.Type = "oneshot";
    script = installScript;
    requiredBy = [ "initrd.target" ];
  };

}
