{ inputs, system }:

let
  inherit (inputs) self nixpkgs;
  inherit (nixpkgs) lib;

  inherit (builtins) readDir;
  inherit (lib) attrNames getAttr listToAttrs nameValuePair;
  inherit (lib.trivial) pipe;

  forAllSystems = lib.genAttrs lib.systems.flakeExposed;

#  packageSets = [ "pkgsLLVM" "pkgsMusl" "pkgsStatic" "pkgsi686Linux" "pkgsx86_64Darwin" ];
#  crossPackageSets = pkgs: attrNames (getAttr "pkgsCross" pkgs);

  autoPackages = import ./unit-packages.nix lib;
  manualPackages = import ./all-packages.nix lib;

  collectedPackages = pkgs: (autoPackages pkgs) // (manualPackages pkgs);

  mkPackages = pkgs: packages:
   let
     mkPackageSets = pset:
       listToAttrs (map (p: nameValuePair p (packages pkgs.${p})) pset);
   in
   packages pkgs;
#   // mkPackageSets packageSets
#   // { pkgsCross = mkPackageSets (crossPackageSets pkgs); };

  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ (self: super: inputs.self.packages.${system}) ];
  };
in
mkPackages pkgs collectedPackages
