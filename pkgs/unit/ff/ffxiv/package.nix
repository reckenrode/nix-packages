{ lib
, stdenvNoCC
, callPackage
, fetchpatch
, desktopToDarwinBundle
, icoutils
, makeDesktopItem
, unzip
, writeShellApplication
, coreutils
, gnused
, pkgsCross
, dxvk
, darwin
, wine64Packages
}:

let
  pname = "ffxiv";
  desktopName = "Final Fantasy XIV (Unofficial)";

  # This is a separate derivation to avoid unnecessary rebuilds that would require downloading
  # multiple GB unnecessarily.
  ffxivClient = callPackage ./ffxiv-client.nix { };

  moltenvk = darwin.moltenvk.overrideAttrs (oldAttrs: {
    patches = oldAttrs.patches ++ [
      (fetchpatch {
        name = "ffxiv-flicker.patch";
        url = "https://github.com/KhronosGroup/MoltenVK/files/9686958/zeroinit.txt";
        hash = "sha256-aORWU7zPTRKSTVF4I0D8rNthdxoZbioZsNUG0/Dq2go=";
      })
#     (fetchpatch {
#       name = "command-storage-optimization.patch";
#       url = "https://patch-diff.githubusercontent.com/raw/KhronosGroup/MoltenVK/pull/1678.patch";
#       hash = "sha256-LEQ1B83V6OsePfb3JVU0KH1DsL+RR28YB7A0aJKa+m0=";
#     })
    ];
  });

  macPreloaderPatches = rec {
    v7_x = [
      { pr = "1616"; hash = "sha256-+DJPtzZDFQ7rUlAxARI3dN8nngRP3UZIvdJSh/U8Tx0="; }
      { pr = "1713"; hash = "sha256-LQCPUPIuy9fN+GUhRTBnOuvbzxhsBAz9VI4gVmelHys="; }
    ] ++ v8_0;
    v8_0 = v8_1;
    v8_1 = [
      { pr = "2129"; hash = "sha256-VscBd7B4CXSJtMxZb7hcuENrFg+/UPjR3/yho6IMfsw="; }
    ] ++ v8_2;
    v8_2 = v8_3;
    v8_3 = [
      { pr = "2329"; hash = "sha256-N2NdKhEzj1/dcw7H/YBzH7L63QS7Cru+vsFOBYhJJ58="; }
    ];
  };

  patches = wine: lib.optionals stdenvNoCC.isDarwin (
    if lib.versions.major wine.version == "7"
    then macPreloaderPatches.v7_x
    else macPreloaderPatches."v${lib.replaceStrings [ "." ] [ "_" ] wine.version}" or [ ]
  );

  fetchWinePatches = { pr, hash }:
    fetchpatch {
      name = "wine-merge_request-${pr}.patch";
      url = "https://gitlab.winehq.org/wine/wine/-/merge_requests/${pr}.patch";
      inherit hash;
    };

  wine64 = wine64Packages.unstable.overrideAttrs (self: super: {
    patches = (super.patches or [ ]) ++ map fetchWinePatches (patches self);
  });

  wine64' = wine64.override {
    inherit moltenvk;
    embedInstallers = true;
  };

  winePrefix = callPackage ./wine-prefix.nix { } {
    inherit gnused;
    wine = wine64';
    extras.files."windows/system32" = [ "${lib.getBin dxvk}/x64" ];
    extras.buildPhase = lib.optionalString stdenvNoCC.isDarwin ''
      echo "Setting up macOS keyboard mappings"
      for value in LeftOptionIsAlt RightOptionIsAlt LeftCommandIsCtrl RightCommandIsCtrl; do
        wine64 reg add 'HKCU\Software\Wine\Mac Driver' /v $value /d Y /f
      done
    '' + ''
      # Set up overrides to make sure DXVK is being used.
      for dll in dxgi d3d11 mcfgthread-12; do
        wine64 reg add 'HKCU\Software\Wine\DllOverrides' /v $dll /d native /f
      done
    '';
  };

  executable = writeShellApplication {
    name = pname;

    runtimeInputs = [ coreutils wine64' ];

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
      WINEDEBUG=-all
      WINEESYNC=1

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

      export WINEPREFIX MVK_CONFIG_LOG_LEVEL WINEDEBUG WINEESYNC \
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
        cp -R "${ffxivClient}/boot" "$FFXIVWINPATH"
        cp "${ffxivClient}/game/ffxivgame.ver" "$FFXIVWINPATH/game"
        find "$FFXIVWINPATH" -type f -exec chmod 644 {} +
        find "$FFXIVWINPATH" -type d -exec chmod 755 {} +
      fi

      # The movies are big and won’t change with patches, so don’t copy them.
      for movie in "${ffxivClient}/game/movie/ffxiv/"*; do
        ln -sfn "$movie" "$FFXIVWINPATH/game/movie/ffxiv/$(basename "$movie")"
      done

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
  inherit (ffxivClient) version;

  nativeBuildInputs = [ icoutils ]
    ++ lib.optional stdenvNoCC.isDarwin desktopToDarwinBundle;

  dontUnpack = true;
  dontConfigure = true;

  buildPhase = ''
    wrestool --type=14 -x ${ffxivClient}/boot/ffxivboot64.exe --output=.
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
    categories = [ "Game" "RolePlaying" ];
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

  passthru.client = ffxivClient;

  meta = {
    description = "Unofficial client for the critically acclaimed MMORPG Final Fantasy XIV. FINAL FANTASY is a registered trademark of Square Enix Holdings Co., Ltd.";
    homepage = "https://www.finalfantasyxiv.com";
    changelog = "https://na.finalfantasyxiv.com/lodestone/special/patchnote_log/";
    maintainers = [ lib.maintainers.reckenrode ];
    # Temporarily until it’s possible to allow unfree flake packages without impurities
    # license = lib.licenses.unfree;
    inherit (wine64.meta) platforms;
    hydraPlatforms = [ ];
  };
})
