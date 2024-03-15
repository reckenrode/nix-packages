# SPDX-License-Identifier: MIT

{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";

  outputs = inputs:
    let
      inherit (inputs) nixpkgs;
      inherit (nixpkgs) lib;

      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    in
    {
      packages = forAllSystems (system:
        import ./pkgs/top-level { inherit inputs system; }
      );
    };
}
