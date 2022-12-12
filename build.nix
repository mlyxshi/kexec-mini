# personal usage
{ pkgs, lib, config, ... }:
let
  kernelTarget = pkgs.hostPlatform.linux-kernel.target;
  arch = pkgs.hostPlatform.uname.processor;
  kernelName = "${kernelTarget}-${arch}";
  initrdName = "initrd-${arch}.zst";
  kexecScriptName = "kexec-${arch}";
  kexec-musl-bin = "kexec-musl-${arch}";

  kexecScript = pkgs.writeScript "kexec-boot" ''
    #!/usr/bin/env bash
    set -e   
    echo "Downloading kexec-musl-bin" && curl -LO https://github.com/mlyxshi/kexec-mini/releases/download/latest/${kexec-musl-bin} && chmod +x ./${kexec-musl-bin}
    echo "Downloading initrd" && curl -LO https://github.com/mlyxshi/kexec-mini/releases/download/latest/${initrdName}
    echo "Downloading kernel" && curl -LO https://github.com/mlyxshi/kexec-mini/releases/download/latest/${kernelName}

    ssh_host_key=$(cat /etc/ssh/ssh_host_ed25519_key | base64 -w0)
    
    for i in /home/$SUDO_USER/.ssh/authorized_keys /root/.ssh/authorized_keys /etc/ssh/authorized_keys.d/root; do
      if [[ -e $i && -s $i ]]; then 
        echo "Get SSH authorized_keys from: $i"
        ssh_authorized_key=$(cat $i | base64 -w0)
        break
      fi     
    done

    echo "Wait... After SSH connection lost, ssh root@ip and enjoy NixOS!"
    ./${kexec-musl-bin} --kexec-syscall-auto --load ./${kernelName} --initrd=./${initrdName}  --append "init=/bin/init ${toString config.boot.kernelParams} ssh_host_key=$ssh_host_key ssh_authorized_key=$ssh_authorized_key $*"
    systemctl --no-block kexec 
  '';
in
{
  system.build.kexec = pkgs.runCommand "buildkexec" { } ''
    mkdir -p $out
    ln -s ${config.system.build.kernel}/${kernelTarget}         $out/${kernelName}
    ln -s ${config.system.build.initialRamdisk}/initrd.zst      $out/${initrdName}
    ln -s ${kexecScript}                                        $out/${kexecScriptName}
    ln -s ${pkgs.pkgsStatic.kexec-tools}/bin/kexec              $out/${kexec-musl-bin}
  '';


  system.build.test = pkgs.writeShellScriptBin "test-vm" ''
    test -f disk.img || ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 disk.img 10G
    flake_url=github:mlyxshi/kexec-mini#nixosConfigurations.demo
    local_test=1
    exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name ${config.networking.hostName} \
      -m 2048 \
      -kernel ${config.system.build.kernel}/${kernelTarget}  -initrd ${config.system.build.initialRamdisk}/initrd.zst  \
      -append "console=ttyS0 init=/bin/init ${toString config.boot.kernelParams} flake_url=$flake_url local_test=$local_test" \
      -no-reboot -nographic \
      -net nic,model=virtio \
      -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
      -drive file=disk.img,format=qcow2,if=virtio \
      -device virtio-rng-pci \
      -bios ${pkgs.OVMF.fd}/FV/OVMF.fd 
  '';
}
