{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  fetchurl,
  requireFile,
  moltenvk,
  wine64Packages,
  enableDXVK,
  enableD3DMetal,
}:

assert enableDXVK -> !enableD3DMetal;
let
  # Upstream Wine is not compatible with the new launcher, but Proton is. Use the jscript and
  # mshtml implementations from Proton with Wine, so the new launcher can be used.
  proton.src = fetchFromGitHub {
    owner = "ValveSoftware";
    repo = "wine";
    rev = "21e0d244da3336a640006e4e25ae28d7612a2c3c";
    hash = "sha256-hd6xNFh97sRgwZpZMQfFCSV29DAZa6rDbSD0zk3jHHw=";
    sparseCheckout = [
      "dlls/mshtml"
      "dlls/jscript"
    ];
  };
  protonCompatPatches = [ ./patches/test.h-compat.patch ];

  wine64Staging = wine64Packages.staging.override (
    {
      embedInstallers = true;
      gstreamerSupport = true;
    }
    // lib.optionalAttrs enableD3DMetal {
      #    d3dmetal = d3dmetal.overrideAttrs (finalAttrs: prevAttrs: {
      #      version = "2.0";
      #      src = requireFile {
      #        name = "Evaluation_environment_for_Windows_games_${finalAttrs.version}_beta_1.dmg";
      #        hash = "sha256-oYC9UoDDJM6SEkLKXzCYrfRNmw7ZOZk/eRjiEWlHFA0=";
      #        url = "https://developer.apple.com/download/all/?q=game%20porting%20toolkit";
      #      };
      #    });
      d3dmetalSupport = true;
    }
  );
  wineVersion = lib.getVersion wine64Staging;
in
wine64Staging.overrideAttrs (super: {
  patches =
    (super.patches or [ ])
    ++
      lib.optionals
        (
          stdenv.hostPlatform.isDarwin
          && lib.versionAtLeast wineVersion "9.1"
          && lib.versionOlder wineVersion "9.9"
        )
        [
          # Causes the axes on PS4 DualShock controllers to be mapped incorrectly, making the game unplayable.
          (fetchpatch {
            url = "https://gitlab.winehq.org/wine/wine/-/commit/173ed7e61b5b80ccd4d268e80c5c15f9fb288aa0.patch";
            hash = "sha256-X/tADAJFX79jlK+EwbWTr3UrMu9qtnPrkIyhjalEXYI=";
            revert = true;
          })
        ]
    ++ protonCompatPatches;

  postUnpack =
    (super.postUnpack or "")
    + ''
      for dir in mshtml jscript; do
        rm -rf "$sourceRoot/dlls/$dir"
        cp -r "${proton.src}/dlls/$dir" "$sourceRoot/dlls/$dir"
        chmod -R u+w "$sourceRoot/dlls/$dir"
      done
    '';
})
