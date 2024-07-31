{ inputs, system }:

let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;

  autoPackages = import ./unit-packages.nix lib;
  manualPackages = import ./all-packages.nix lib;

  collectedPackages = pkgs: (autoPackages pkgs) // (manualPackages pkgs);

  mkPackages = pkgs: packages: packages pkgs;

  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ (self: super: inputs.self.packages.${system}) ];
  };
in
mkPackages pkgs collectedPackages
