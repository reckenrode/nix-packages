{ lib
, stdenvNoCC
, fetchurl
, unzip
, wine64Packages
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ffxiv";
  version = "1.0.8";

  # The Windows installer is a 32-bit app, which won’t run on Darwin because WoW64 is not yet
  # supported there with upstream Wine. The Mac client also has Bink-encoded video files that are
  # needed because the WMV-encoded ones in the Windows client don’t work with Wine by default.
  src = fetchurl {
    url = "https://mac-dl.ffxiv.com/cw/finalfantasyxiv-${finalAttrs.version}.zip";
    sha256 = "sha256-CBzl0gxKyQpkyu8kTZaFYFEJQC0vMlObRBGGOLOxmNA=";
  };

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/bin
    bootstrap_path='Contents/SharedSupport/finalfantasyxiv/support/published_Final_Fantasy/drive_c/Program Files (x86)/SquareEnix/FINAL FANTASY XIV - A Realm Reborn'
    cp -Rv "$bootstrap_path/boot" "$bootstrap_path/game" $out
    rm -v $out/boot/ffxiv_dx11.dxvk-cache-base
  '';

  meta = {
    description = "FINAL FANTASY is a registered trademark of Square Enix Holdings Co., Ltd.";
    homepage = "https://www.finalfantasyxiv.com";
    changelog = "https://na.finalfantasyxiv.com/lodestone/special/patchnote_log/";
    maintainers = [ lib.maintainers.reckenrode ];
    # Temporarily until it’s possible to allow unfree flake packages without impurities
    # license = lib.licenses.unfree;
    inherit (wine64Packages.unstable.meta) platforms;
    hydraPlatforms = [ ];
  };
})
