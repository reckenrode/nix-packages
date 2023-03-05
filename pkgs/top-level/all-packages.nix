# SPDX-License-Identifier: MIT

{ inputs }:

let
  inherit (inputs) self nixpkgs;
  inherit (nixpkgs) lib;

  inherit (builtins) readDir;

  inherit (lib) attrNames concatMap elemAt filter filterAttrs getAttr listToAttrs nameValuePair
    pathExists substring toLower foldl';

  inherit (lib.trivial) pipe;

  forAllSystems = lib.genAttrs lib.systems.flakeExposed;

  enumeratePackages = basePath:
    let
      childPaths = path: attrNames (filterAttrs (_: type: type == "directory") (readDir path));

      isShardedCorrectly = path: elemAt path 0 == toLower (substring 0 2 (elemAt path 1));

      mkPackagePath = shard: package: [ shard package "package.nix" ];

      packagesInShard = shard: map (mkPackagePath shard) (childPaths (basePath + "/${shard}"));

      renderPath = foldl' (path: elem: path + "/${elem}");
    in
    pipe (childPaths basePath) [
      (concatMap packagesInShard)
      (filter isShardedCorrectly)
      (map (renderPath basePath))
      (filter pathExists)
    ];

  packages = enumeratePackages ../unit;

  mkPackage = pkgs: path: {
    name = baseNameOf (dirOf path);
    value = pkgs.callPackage path { };
  };

  mkPackages = pkgs: packages: listToAttrs (map (mkPackage pkgs) packages);

  packageSets = [ "pkgsLLVM" "pkgsMusl" "pkgsStatic" "pkgsi686Linux" "pkgsx86_64Darwin" ];
  crossPackageSets = pkgs: attrNames (getAttr "pkgsCross" pkgs);

  mkPackageSets = pkgs: packages:
    let
      mkPackageSet = pkgs: pkgset: nameValuePair pkgset (mkPackages (getAttr pkgset pkgs) packages);
    in
      mkPackages pkgs packages
      // listToAttrs (map (mkPackageSet pkgs) packageSets)
      // { pkgsCross = listToAttrs (map (mkPackageSet pkgs.pkgsCross) (crossPackageSets pkgs)); };
in
forAllSystems (system:
  let
    pkgs = nixpkgs.legacyPackages.${system};
  in
  mkPackageSets pkgs packages
)
