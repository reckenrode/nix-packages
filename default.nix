# This `default.nix` is provided only for compatibility with `update-source-version`.
# It blindly overlays the flake’s packages over `<nixpkgs>`. Use at your own risk.
let
  flakePackages = (builtins.getFlake (toString ./.)).outputs.packages;
in
import <nixpkgs> { overlays = [ (self: super: flakePackages.${builtins.currentSystem}) ]; }
