lib: pkgs:

{
  ffxiv = pkgs.callPackage ../unit/ff/ffxiv/package.nix {
    inherit (pkgs.darwin) moltenvk;
    wine64 = pkgs.wine64Packages.unstable;
  };
}
