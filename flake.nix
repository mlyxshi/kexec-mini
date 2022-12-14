{
  # Systemd stage 1 networkd: https://github.com/NixOS/nixpkgs/pull/169116
  inputs.nixpkgs.url = "github:nixos/nixpkgs/pull/169116/head";
  outputs = { self, nixpkgs }:
    let
      commonModules = [
        ./host.nix
        ./build.nix
        ./initrd
      ];
    in
    {
      nixosConfigurations = {
        "kexec-x86_64" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = commonModules;
        };

        "kexec-aarch64" = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = commonModules;
        };

        "demo" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./demo.nix ];
        };
      };

      packages.x86_64-linux.default = self.nixosConfigurations."kexec-x86_64".config.system.build.test;
      packages.x86_64-linux.test0 = self.nixosConfigurations."kexec-x86_64".config.system.build.test0;
    };

}
