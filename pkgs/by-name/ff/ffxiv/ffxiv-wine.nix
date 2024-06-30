{
  lib,
  stdenv,
  fetchgit,
  fetchpatch,
  fetchurl,
  requireFile,
  d3dmetal,
  moltenvk,
  wine64Packages,
  enableDXVK,
  enableD3DMetal,
}:

assert enableDXVK -> !enableD3DMetal;
let
  moltenvk' = moltenvk.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      (
        if lib.versionOlder (lib.getVersion moltenvk) "1.2.9" then
          fetchpatch {
            name = "ffxiv-flicker.patch";
            url = "https://github.com/KhronosGroup/MoltenVK/files/9686958/zeroinit.txt";
            hash = "sha256-aORWU7zPTRKSTVF4I0D8rNthdxoZbioZsNUG0/Dq2go=";
          }
        else
          ./ffxiv-flicker.patch
      )
      #     (fetchpatch {
      #       name = "command-storage-optimization.patch";
      #       url = "https://patch-diff.githubusercontent.com/raw/KhronosGroup/MoltenVK/pull/1678.patch";
      #       hash = "sha256-LEQ1B83V6OsePfb3JVU0KH1DsL+RR28YB7A0aJKa+m0=";
      #     })
    ];
  });

  # Upstream Wine is not compatible with the new launcher, but Proton is. Use the jscript and
  # mshtml implementations from Proton with Wine, so the new launcher can be used.
  proton.src = fetchgit {
    url = "https://github.com/ValveSoftware/wine.git";
    rev = "21e0d244da3336a640006e4e25ae28d7612a2c3c";
    hash = "sha256-hd6xNFh97sRgwZpZMQfFCSV29DAZa6rDbSD0zk3jHHw=";
    sparseCheckout = [
      "dlls/mshtml"
      "dlls/jscript"
    ];
  };
  protonCompatPatches = [ ./test.h-compat.patch ];

  msyncPatch =
    if lib.versionAtLeast "9.12" (lib.getVersion wine64Staging) then
      [ ./msync-staging-9.12.patch ]
    else
      [
        (fetchurl {
          name = "msync-staging-${wineVersion}.patch";
          url = "https://github.com/marzent/wine-msync/raw/4956fb93528d728a9941642b24400b7ebf000465/msync-staging.patch";
          postFetch = ''
            sed -E \
              -e '/-#define SERVER_PROTOCOL_VERSION/,+4d' \
              -e 's/@@ -6629,11 \+6725,16 @@/@@ -6629,7 +6725,12 @@/' \
              -e '/\+\+\+ b\/dlls\/ntdll\/unix\/sync\.c/,/---/{/118,7/,+7d}' \
              -i "$out"
          '';
          hash = "sha256-byjcE9RNE3VA0+l8NCYjSNSsVOxzSXoTF6ioxn/PGJE=";
        })
      ];

  wine64Staging = wine64Packages.staging.override (
    {
      embedInstallers = true;
      gstreamerSupport = true;
    }
    // lib.optionalAttrs enableDXVK { moltenvk = moltenvk'; }
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
        (stdenv.isDarwin && lib.versionAtLeast wineVersion "9.1" && lib.versionOlder wineVersion "9.9")
        [
          # Causes the axes on PS4 DualShock controllers to be mapped incorrectly, making the game unplayable.
          (fetchpatch {
            url = "https://gitlab.winehq.org/wine/wine/-/commit/173ed7e61b5b80ccd4d268e80c5c15f9fb288aa0.patch";
            hash = "sha256-X/tADAJFX79jlK+EwbWTr3UrMu9qtnPrkIyhjalEXYI=";
            revert = true;
          })
        ]
    ++ protonCompatPatches
    ++ msyncPatch;

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
