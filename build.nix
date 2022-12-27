# personal usage
{ pkgs, lib, config, ... }:
let
  kernelTarget = pkgs.hostPlatform.linux-kernel.target;

  kexecScript-common = ''
    for i in /etc/ssh/ssh_host_ed25519_key /persist/etc/ssh/ssh_host_ed25519_key; do
      if [[ -e $i && -s $i ]]; then 
        echo "Get ssh_host_ed25519_key from: $i"
        ssh_host_key=$(cat $i | base64 -w0)
        break
      fi     
    done
    
    for i in /home/$SUDO_USER/.ssh/authorized_keys /root/.ssh/authorized_keys /etc/ssh/authorized_keys.d/root; do
      if [[ -e $i && -s $i ]]; then 
        echo "Get authorized_keys      from: $i"
        ssh_authorized_key=$(cat $i | base64 -w0)
        break
      fi     
    done
    
    ./kexec-bin --kexec-syscall-auto --load ./kernel --initrd=./initrd  --append "init=/bin/init ${toString config.boot.kernelParams} ssh_host_key=$ssh_host_key ssh_authorized_key=$ssh_authorized_key $*"
    ./kexec-bin -e
  '';

  kexecScript-x86_64 = pkgs.writeTextDir "script/kexec" (''
    #!/usr/bin/env bash
    set -e   
    
    echo "Downloading kexec-musl-bin" && curl -LO https://hydra.mlyxshi.com/job/kexec/build/x86_64/latest/download-by-type/file/kexec-bin && chmod +x ./kexec-bin
    echo "Downloading initrd" && curl -LO https://hydra.mlyxshi.com/job/kexec/build/x86_64/latest/download-by-type/file/initrd
    echo "Downloading kernel" && curl -LO https://hydra.mlyxshi.com/job/kexec/build/x86_64/latest/download-by-type/file/kernel
  '' + kexecScript-common);

  kexecScript-aarch64 = pkgs.writeTextDir "script/kexec" (''
    #!/usr/bin/env bash
    set -e  

    echo "Downloading kexec-musl-bin" && curl -LO https://hydra.mlyxshi.com/job/kexec/build/aarch64/latest/download-by-type/file/kexec-bin && chmod +x ./kexec-bin
    echo "Downloading initrd" && curl -LO https://hydra.mlyxshi.com/job/kexec/build/aarch64/latest/download-by-type/file/initrd
    echo "Downloading kernel" && curl -LO https://hydra.mlyxshi.com/job/kexec/build/aarch64/latest/download-by-type/file/kernel
  '' + kexecScript-common);

  ipxeScript-x86_64 = pkgs.writeTextDir "script/ipxe" ''
    #!ipxe
    kernel https://hydra.mlyxshi.com/job/kexec/build/x86_64/latest/download-by-type/file/kernel initrd=initrd init=/bin/init ${toString config.boot.kernelParams} ''${cmdline}
    initrd https://hydra.mlyxshi.com/job/kexec/build/x86_64/latest/download-by-type/file/kernel
    boot
  '';

  ipxeScript-aarch64 = pkgs.writeTextDir "script/ipxe" ''
    #!ipxe
    kernel https://hydra.mlyxshi.com/job/kexec/build/aarch64/latest/download-by-type/file/kernel initrd=initrd init=/bin/init ${toString config.boot.kernelParams} ''${cmdline}
    initrd https://hydra.mlyxshi.com/job/kexec/build/aarch64/latest/download-by-type/file/initrd
    boot
  '';

in
{

  system.build = {

    x86_64 = pkgs.symlinkJoin {
      name = "kexec";
      paths = [
        config.system.build.kernel
        config.system.build.initialRamdisk
        kexecScript-x86_64
        ipxeScript-x86_64
        pkgs.pkgsStatic.kexec-tools
      ];
      postBuild = ''
        mkdir -p $out/nix-support
        cat > $out/nix-support/hydra-build-products <<EOF
        file initrd $out/initrd
        file kernel $out/${kernelTarget}
        file kexec $out/script/kexec
        file ipex $out/script/ipxe
        file kexec-bin $out/bin/kexec
        EOF
      '';
    };

    aarch64 = pkgs.symlinkJoin {
      name = "kexec";
      paths = [
        config.system.build.kernel
        config.system.build.initialRamdisk
        kexecScript-aarch64
        ipxeScript-aarch64
        pkgs.pkgsStatic.kexec-tools
      ];
      postBuild = ''
        mkdir -p $out/nix-support
        cat > $out/nix-support/hydra-build-products <<EOF
        file initrd $out/initrd
        file kernel $out/${kernelTarget}
        file kexec $out/script/kexec
        file ipex $out/script/ipxe
        file kexec-bin $out/bin/kexec
        EOF
      '';
    };

  };


  system.build.test = pkgs.writeShellScriptBin "test-vm" ''
    test -f disk.img || ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 disk.img 10G
    host=qemu-test-x64
    local_test=1
    exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name ${config.networking.hostName} \
      -m 2048 \
      -kernel ${config.system.build.kernel}/${kernelTarget}  -initrd ${config.system.build.initialRamdisk}/initrd.zst  \
      -append "console=ttyS0 init=/bin/init ${toString config.boot.kernelParams} host=$host local_test=$local_test" \
      -no-reboot -nographic \
      -net nic,model=virtio \
      -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
      -drive file=disk.img,format=qcow2,if=virtio \
      -device virtio-rng-pci \
      -bios ${pkgs.OVMF.fd}/FV/OVMF.fd 
  '';

  # Fast Test without Install 
  system.build.test0 = pkgs.writeShellScriptBin "test-vm" ''
    test -f disk.img || ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 disk.img 10G
    exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name ${config.networking.hostName} \
      -m 2048 \
      -kernel ${config.system.build.kernel}/${kernelTarget}  -initrd ${config.system.build.initialRamdisk}/initrd.zst  \
      -append "console=ttyS0 init=/bin/init ${toString config.boot.kernelParams}" \
      -no-reboot -nographic \
      -net nic,model=virtio \
      -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
      -drive file=disk.img,format=qcow2,if=virtio \
      -device virtio-rng-pci \
      -bios ${pkgs.OVMF.fd}/FV/OVMF.fd 
  '';
}
