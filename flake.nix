{
  description = "A minimal initrd, capable of running sshd and nix.";
  # this is a temporary fork including the changes from
  # https://github.com/NixOS/nixpkgs/pull/169116/files
  # (rebased on master from time to time)
  inputs.nixpkgs.url = "github:phaer/nixpkgs/nix-dabei";


  outputs = { self, nixpkgs }:
    let
      commonModules = [
        ./host.nix
        ./initrd.nix
        ./kernelModules.nix
        ./install.nix
        ./build.nix
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
      };
    };

}
