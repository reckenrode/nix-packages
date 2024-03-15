# SPDX-License-Identifier: MIT

lib: pkgs:

let
  inherit (builtins) readDir;
  inherit (lib) attrNames concatMap elemAt filter filterAttrs listToAttrs pathExists substring toLower foldl';
  inherit (lib.trivial) pipe;

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

  mkUnitPackage = pkgs: path: {
    name = baseNameOf (dirOf path);
    value = pkgs.callPackage path { };
  };
in
listToAttrs (map (mkUnitPackage pkgs) (enumeratePackages ../by-name))
