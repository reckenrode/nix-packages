{ lib
, stdenvNoCC
, fetchurl
, writeScript
, unzip
, wine64Packages
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ffxiv-client";
  version = "1.1.2";

  # The Windows installer is a 32-bit app, which won’t run on Darwin because WoW64 is not yet
  # supported there with upstream Wine. The Mac client also has Bink-encoded video files that are
  # needed because the WMV-encoded ones in the Windows client don’t work with Wine by default.
  src = fetchurl {
    url = "https://mac-dl.ffxiv.com/cw/finalfantasyxiv-${finalAttrs.version}.zip";
    hash = "sha256-p44Q1tSsYpvCCz1PVHUJ4Z/e6EpNPdw9FI5bo3PP9qk=";
  };

  nativeBuildInputs = [ unzip ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p "$out"
    bootstrap_path='Contents/SharedSupport/finalfantasyxiv/support/published_Final_Fantasy/drive_c/Program Files (x86)/SquareEnix/FINAL FANTASY XIV - A Realm Reborn'
    cp -Rv "$bootstrap_path/boot" "$bootstrap_path/game" "$out"
    rm -v "$out/boot"/*cache*
  '';

  # The hash is going to be the same regardless of system, so hardcode to allow the update script
  # to be run on unsupported platforms like aarch64-darwin.
  passthru.updateScript = writeScript "update-ffxiv-client" ''
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p curl yq common-updater-scripts
    set -eu -o pipefail
    FFXIV_SPARKLE_FEED=https://mac-dl.ffxiv.com/cw/finalfantasy-mac.xml
    version=$(curl "$FFXIV_SPARKLE_FEED" | xq -r '.rss.channel.item.enclosure."@sparkle:version"')
    update-source-version ffxiv "$version" \
      --system=x86_64-darwin --source-key=client.src --file=pkgs/unit/ff/ffxiv/ffxiv-client.nix
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
