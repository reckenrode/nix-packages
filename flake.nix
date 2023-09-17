# SPDX-License-Identifier: MIT

{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";

  outputs = inputs: {
    packages = import ./pkgs/top-level inputs;
  };
}
