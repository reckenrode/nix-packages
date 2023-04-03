# SPDX-License-Identifier: MIT

{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

  outputs = inputs: {
    packages = import ./pkgs/top-level inputs;
  };
}
