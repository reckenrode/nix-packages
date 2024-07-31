{
  lib,
  stdenvNoCC,
  callPackage,
  desktopToDarwinBundle,
  ffxiv,
  makeDesktopItem,
  mk-wine-prefix,
  writeShellApplication,
  coreutils,
  darwin,
  dxvk,
  icoutils,
  enableDXVK ? true,
  enableD3DMetal ? false, # Currently broken
}:

let
  pname = "ffxiv";
  desktopName = "Final Fantasy XIV (Unofficial)";

  winePrefix = mk-wine-prefix {
    inherit (ffxiv) wine;
    extras.files = lib.optionalAttrs enableDXVK { "windows/system32" = [ "${lib.getBin dxvk}/x64" ]; };
    extras.buildPhase =
      lib.optionalString stdenvNoCC.isDarwin ''
        echo "Setting up macOS keyboard mappings"
        for value in LeftOptionIsAlt RightOptionIsAlt LeftCommandIsCtrl RightCommandIsCtrl; do
          wine64 reg add 'HKCU\Software\Wine\Mac Driver' /v $value /d Y /f
        done
      ''
      + lib.optionalString enableDXVK ''
        # Set up overrides to make sure DXVK is being used.
        for dll in dxgi d3d11 mcfgthread-12; do
          wine64 reg add 'HKCU\Software\Wine\DllOverrides' /v $dll /d native /f
        done
      '';
  };

  executable = writeShellApplication {
    name = pname;

    runtimeInputs = [
      coreutils
      ffxiv.wine
    ];

    text = ''
      # Set paths for the game and its configuration.
      WINEPREFIX="''${XDG_DATA_HOME:-"$HOME/.local/share"}/ffxiv"
      FFXIVCONFIG="''${XDG_CONFIG_HOME:-"$HOME/.config"}/ffxiv"

      DXVK_CONFIG_FILE=$FFXIVCONFIG/dxvk.conf
      DXVK_LOG_PATH="''${XDG_STATE_HOME:-"$HOME/.local/state"}/ffxiv"
      DXVK_STATE_CACHE_PATH="''${XDG_CACHE_HOME:-"$HOME/.cache"}/ffxiv"

      mkdir -p "$DXVK_LOG_PATH" "$DXVK_STATE_CACHE_PATH"
      # Transform the log and state cache paths to a Windows-style path
      DXVK_CONFIG_FILE="z:''${DXVK_CONFIG_FILE//\//\\}"
      DXVK_LOG_PATH="z:''${DXVK_LOG_PATH//\//\\}"
      DXVK_STATE_CACHE_PATH="z:''${DXVK_STATE_CACHE_PATH//\//\\}"

      WINEDOCUMENTS="$WINEPREFIX/dosdevices/c:/users/$(whoami)/Documents"
      FFXIVWINCONFIG="$WINEDOCUMENTS/My Games/FINAL FANTASY XIV - A Realm Reborn"
      FFXIVWINPATH="$WINEPREFIX/dosdevices/f:/FFXIV"

      # Enable ESYNC and disable logging
      WINEDEBUG=''${WINEDEBUG:--all}
      WINEESYNC=1
      WINEMSYNC=1

      # Darwin MoltenVK compatibility settings
      if [[ "$(${coreutils}/bin/uname -s)" = "Darwin" ]]; then
        MVK_CONFIG_LOG_LEVEL=0
        MVK_CONFIG_RESUME_LOST_DEVICE=1
        MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE=1

        # Detect whether FFXIV is running on Apple Silicon
        if /usr/bin/arch -arch arm64 -c /bin/echo &> /dev/null; then
          # Enable Metal fences on Apple GPUs for better performance.
          MVK_CONFIG_FULL_IMAGE_VIEW_SWIZZLE=0
        else
          MVK_CONFIG_FULL_IMAGE_VIEW_SWIZZLE=1 # Required by DXVK on Intel and AMD GPUs.
        fi
        export MVK_CONFIG_RESUME_LOST_DEVICE \
          MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE MVK_CONFIG_FULL_IMAGE_VIEW_SWIZZLE
      fi

      export WINEPREFIX MVK_CONFIG_LOG_LEVEL WINEDEBUG WINEESYNC WINEMSYNC \
        DXVK_CONFIG_FILE DXVK_LOG_PATH DXVK_STATE_CACHE_PATH

      mkdir -p "$WINEPREFIX/dosdevices" "$WINEPREFIX/drive_c" "$WINEPREFIX/drive_f"
      ln -sfn "$WINEPREFIX/drive_c" "$WINEPREFIX/dosdevices/c:"
      ln -sfn "$WINEPREFIX/drive_f" "$WINEPREFIX/dosdevices/f:"

      for folder in "${winePrefix}/drive_c"/*; do
        ln -sfn "$folder" "$WINEPREFIX/drive_c"
      done

      ln -sfn / "$WINEPREFIX/dosdevices/z:"

      # Avoid copying the default registry files unless they have changed.
      # Only copying them when necessary improves startup performance.
      for regfile in user.reg system.reg; do
        registryFile="${winePrefix}/$regfile"
        registryDigest="$WINEPREFIX/$regfile.digest"
        if ! sha256sum -c <(printf "%s  %s" "$(cat "$registryDigest")" "$registryFile") > /dev/null; then
          cp "$registryFile" "$WINEPREFIX"
          sha256sum "$registryFile" | cut -d' ' -f1 > "$registryDigest"
        fi
      done

      # Avoid spurious TCC warnings on Darwin.
      for path in Desktop Documents Downloads Music Pictures Videos AppData/Roaming/Microsoft/Windows/Templates; do
        folder="$WINEPREFIX/dosdevices/c:/users/$(whoami)/$path"
        if [[ -L "$folder" ]]; then
          rm "$folder"
        fi
        if [[ ! -d "$folder" ]]; then
          mkdir -p "$folder"
        fi
      done

      mkdir -p "$FFXIVWINPATH/game/movie/ffxiv"

      if [[ ! -f "$FFXIVWINPATH/game/ffxivgame.ver" ]]; then
        cp -R "${ffxiv.client}/boot" "$FFXIVWINPATH"
        cp "${ffxiv.client}/game/ffxivgame.ver" "$FFXIVWINPATH/game"
        find "$FFXIVWINPATH" -type f -exec chmod 644 {} +
        find "$FFXIVWINPATH" -type d -exec chmod 755 {} +
      fi

      # Set up XDG-compliant configuration for the game.
      if [[ -d "$FFXIVCONFIG" ]]; then
        # echo "dxvk.enableAsync = true" > "$FFXIVCONFIG/dxvk.conf"
        ln -sfn "$FFXIVCONFIG/dxvk.conf" "$FFXIVWINPATH/boot/dxvk.conf"
      fi

      mkdir -p "$(dirname "$FFXIVWINCONFIG")" "$FFXIVCONFIG"
      ln -sfn "$FFXIVCONFIG" "$FFXIVWINCONFIG"

      cd "$FFXIVWINPATH/boot" && wine64 ffxivboot64.exe
    '';
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  inherit (finalAttrs.passthru.client) version;

  strictDeps = true;

  nativeBuildInputs = [ icoutils ] ++ lib.optional stdenvNoCC.isDarwin desktopToDarwinBundle;

  dontUnpack = true;
  dontConfigure = true;

  buildPhase = ''
    wrestool --type=14 -x ${finalAttrs.passthru.client}/boot/ffxivboot64.exe --output=.
    icotool -x ffxivboot64.exe_14_103_1041.ico --output=.

    local -rA widths=([1]=256 [2]=48 [3]=32 [4]=16)
    local -rA retina_widths=([1]=128 [2]=24 [3]=16 [4]=na)

    for index in "''${!widths[@]}"; do
      local width=''${widths[$index]}
      local retina_width=''${retina_widths[$index]}
      local res=''${width}x''${width}

      local -a icondirs=("$res/apps")
      if [[ $retina_width != 'na' ]]; then
        icondirs+=("''${retina_width}x''${retina_width}@2/apps")
      fi

      for icondir in "''${icondirs[@]}"; do
        mkdir -p "$icondir"
        cp ffxivboot64.exe_14_103_1041_''${index}_''${res}x32.png "$icondir/ffxiv.png"
      done
    done
  '';

  desktopItem = makeDesktopItem {
    name = finalAttrs.pname;
    exec = finalAttrs.pname;
    icon = finalAttrs.pname;
    type = "Application";
    comment = finalAttrs.meta.description;
    inherit desktopName;
    categories = [
      "Game"
      "RolePlaying"
    ];
    prefersNonDefaultGPU = true;
    startupNotify = false;
    extraConfig = {
      StartupWMClass = "ffxivboot64.exe";
      X-macOS-SquircleIcon = "false";
    };
  };

  installPhase = ''
    shopt -s extglob

    mkdir -p $out/share/icons/hicolor
    ln -s ${executable}/bin $out/bin
    cp -Rv {??,???}x{??,???}?(@2) $out/share/icons/hicolor
    ln -sv "${finalAttrs.desktopItem}/share/applications" "$out/share/applications"
  '';

  # This is a separate derivation to avoid unnecessary rebuilds that would require downloading
  # multiple GB unnecessarily.
  passthru.client = callPackage ./ffxiv-client.nix { };

  passthru.wine = callPackage ./ffxiv-wine.nix {
    inherit (darwin) moltenvk;
    inherit enableDXVK enableD3DMetal;
  };

  __structuredAttrs = true;

  meta = {
    description = "Unofficial client for the critically acclaimed MMORPG Final Fantasy XIV. FINAL FANTASY is a registered trademark of Square Enix Holdings Co., Ltd.";
    homepage = "https://www.finalfantasyxiv.com";
    changelog = "https://na.finalfantasyxiv.com/lodestone/special/patchnote_log/";
    maintainers = [ lib.maintainers.reckenrode ];
    # Temporarily until it’s possible to allow unfree flake packages without impurities
    # license = lib.licenses.unfree;
    inherit (finalAttrs.passthru.wine.meta) platforms;
    hydraPlatforms = [ ];
  };
})
