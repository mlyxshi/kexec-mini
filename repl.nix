let
  flake = builtins.getFlake (toString ./.);
  nixpkgs = flake.inputs.nixpkgs;
  pkgs = import nixpkgs { system = builtins.currentSystem; };
  lib = pkgs.lib;
in
{ }

// builtins
// pkgs
// lib
// flake
