{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchzip,
  desktopToDarwinBundle,
  makeDesktopItem,
  makeWrapper,
  mk-wine-prefix,
  writeShellApplication,
  coreutils,
  dawntrail-benchmark,
  dxvk,
  ffxiv,
  icoutils,
  python3,
  enableDXVK ? true,
  enableD3DMetal ? false, # Currently broken
}:

let
  desktopItem = makeDesktopItem {
    desktopName = "Dawntrail Benchmark (Unofficial)";
    name = "dawntrail-benchmark";
    exec = "ffxiv-benchmark-launcher";
    icon = "ffxiv-benchmark-launcher";
    type = "Application";
    comment = dawntrail-benchmark.meta.description;
    categories = [
      "Game"
      "RolePlaying"
    ];
    prefersNonDefaultGPU = true;
    startupNotify = false;
    extraConfig = {
      StartupWMClass = "ffxiv_dx11.exe";
      X-macOS-SquircleIcon = "false";
    };
  };

  defaultEnvironment =
    [
      "DXVK_HUD=fps,gpuload"
      "WINEDEBUG=-all"
      "WINEESYNC=1"
    ]
    ++ lib.optionals stdenvNoCC.isLinux [ "WINEFSYNC=1" ]
    ++ lib.optionals stdenvNoCC.isDarwin [
      "WINEMSYNC=1"
      "MVK_CONFIG_LOG_LEVEL=0"
    ];

  benchmark = fetchzip {
    name = "ffxiv-dawntrail-benchmark-1.1";
    url = "https://download.finalfantasyxiv.com/Z27rsYvWfCa3iTaM/ffxiv-dawntrail-bench_v11.zip";
    stripRoot = false;
    hash = "sha256-VBi3JEe8mTjbptPaR/TPiKcjbyU6x+nr58DcYg4qv9k=";
  };

  benchmarkPrefix = mk-wine-prefix {
    inherit wine;
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
    name = "ffxiv-benchmark-launcher";

    runtimeInputs = [
      coreutils
      wine
    ];

    text = ''
      # Set paths for the game and its configuration.
      WINEPREFIX="''${XDG_DATA_HOME:-"$HOME/.local/share"}/ffxiv_benchmark"
      FFXIVCONFIG="''${XDG_CONFIG_HOME:-"$HOME/.config"}/ffxiv"
      FFXIVBENCHCONFIG="''${XDG_CONFIG_HOME:-"$HOME/.config"}/ffxiv_benchmark"
      FFXIVDATA="''${XDG_STATE_HOME:-"$HOME/.local/state"}/ffxiv_benchmark/data"

      DXVK_CONFIG_FILE=$FFXIVBENCHCONFIG/dxvk.conf
      DXVK_LOG_PATH="''${XDG_STATE_HOME:-"$HOME/.local/state"}/ffxiv_benchmark"
      DXVK_STATE_CACHE_PATH="''${XDG_CACHE_HOME:-"$HOME/.cache"}/ffxiv_bechmark"

      mkdir -p "$DXVK_LOG_PATH" "$DXVK_STATE_CACHE_PATH"
      # Transform the log and state cache paths to a Windows-style path
      DXVK_CONFIG_FILE="z:''${DXVK_CONFIG_FILE//\//\\}"
      DXVK_LOG_PATH="z:''${DXVK_LOG_PATH//\//\\}"
      DXVK_STATE_CACHE_PATH="z:''${DXVK_STATE_CACHE_PATH//\//\\}"

      WINEDOCUMENTS="$WINEPREFIX/dosdevices/c:/users/$(whoami)/Documents"
      FFXIVWINCONFIG="$WINEDOCUMENTS/My Games/FINAL FANTASY XIV - A Realm Reborn"
      FFXIVBENCHWINCONFIG="$WINEDOCUMENTS/My Games/FINAL FANTASY XIV - A Realm Reborn (Benchmark)"
      FFXIVWINPATH="$WINEPREFIX/dosdevices/f:/FFXIV_Benchmark"

      # Darwin MoltenVK compatibility settings
      if [[ "$(uname -s)" = "Darwin" ]]; then
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

      export WINEPREFIX DXVK_CONFIG_FILE DXVK_LOG_PATH DXVK_STATE_CACHE_PATH

      mkdir -p "$WINEPREFIX/dosdevices" "$WINEPREFIX/drive_c" "$WINEPREFIX/drive_f"
      ln -sfn "$WINEPREFIX/drive_c" "$WINEPREFIX/dosdevices/c:"
      ln -sfn "$WINEPREFIX/drive_f" "$WINEPREFIX/dosdevices/f:"

      for folder in "${benchmarkPrefix}/drive_c"/*; do
        ln -sfn "$folder" "$WINEPREFIX/drive_c"
      done

      ln -sfn / "$WINEPREFIX/dosdevices/z:"

      # Avoid copying the default registry files unless they have changed.
      # Only copying them when necessary improves startup performance.
      for regfile in user.reg system.reg; do
        registryFile="${benchmarkPrefix}/$regfile"
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

      mkdir -p "$FFXIVWINPATH"

      if [[ ! -f "$FFXIVWINPATH/ffxiv-dawntrail-bench.exe" ]]; then
        for file in asset ffxiv-dawntrail-bench.exe game; do
          ln -s "${benchmark}/$file" "$FFXIVWINPATH"
        done
        find "$FFXIVWINPATH" -type f -exec chmod 644 {} +
        find "$FFXIVWINPATH" -type d -exec chmod 755 {} +
      fi

      if [[ ! -e "$FFXIVWINPATH/data" ]]; then
        mkdir -p "$FFXIVDATA" "$FFXIVBENCHCONFIG/screenshots"
        ln -s "$FFXIVDATA" "$FFXIVWINPATH/data"
        ln -s "$FFXIVBENCHCONFIG/screenshots" "$FFXIVWINPATH/screenshots"
      fi

      # Set up XDG-compliant configuration for the game.
      if [[ -d "$FFXIVBENCHCONFIG" ]]; then
        # echo "dxvk.enableAsync = true" > "$FFXIVBENCHCONFIG/dxvk.conf"
        ln -sfn "$FFXIVBENCHCONFIG/dxvk.conf" "$FFXIVWINPATH/dxvk.conf"
      fi

      mkdir -p "$(dirname "$FFXIVWINCONFIG")" "$FFXIVCONFIG"
      ln -sfn "$FFXIVCONFIG" "$FFXIVWINCONFIG"

      mkdir -p "$(dirname "$FFXIVBENCHWINCONFIG")" "$FFXIVBENCHCONFIG"
      ln -sfn "$FFXIVBENCHCONFIG" "$FFXIVBENCHWINCONFIG"

      '${launcher-python3}/bin/python3' '@launcher-path@/libexec/ffxiv-benchmark.py' "$FFXIVWINPATH"
    '';
  };

  launcher-python3 = python3.withPackages (
    ps: with ps; [
      pyqt6
      pyqt6-sip
    ]
  );

  inherit (ffxiv.override { inherit enableDXVK enableD3DMetal; }) wine;
in
stdenvNoCC.mkDerivation {
  name = "dawntrail-benchmark";
  version = "1.1";

  src = [
    (fetchFromGitHub {
      name = "ffxiv-benchmark-launcher";
      owner = "doitsujin";
      repo = "ffxiv-benchmark-launcher";
      rev = "1a3064e994394da85d80a8f7017a766e771cc5fd";
      hash = "sha256-tJilw5pX/1S8d6JWaz/U2BDTNVPD+gvAP61DYiUneds=";
    })
  ];

  # Tweak the script to work better with the Wine environment being built.
  patches = [ ./0001-nixpkgs-compatibility-patches.patch ];

  strictDeps = true;

  nativeBuildInputs = [ icoutils ] ++ lib.optional stdenvNoCC.isDarwin desktopToDarwinBundle;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    wrestool --type=14 -x ${benchmark}/ffxiv-dawntrail-bench.exe --output=.
    icotool -x ffxiv-dawntrail-bench.exe_14_32512_0.ico --output=.

    declare -rA widths=([1]=256 [2]=48 [3]=32 [4]=16)
    declare -rA retina_widths=([1]=128 [2]=24 [3]=16 [4]=na)

    for index in "''${!widths[@]}"; do
      declare width=''${widths[$index]}
      declare retina_width=''${retina_widths[$index]}
      declare res=''${width}x''${width}

      declare -a icondirs=("$res/apps")
      if [[ $retina_width != 'na' ]]; then
        icondirs+=("''${retina_width}x''${retina_width}@2/apps")
      fi

      for icondir in "''${icondirs[@]}"; do
        iconfile=ffxiv-dawntrail-bench.exe_14_32512_0_''${index}_''${res}x32.png
        if [[ -f "$iconfile" ]]; then
          mkdir -p "$icondir"
          cp "$iconfile" "$icondir/ffxiv-benchmark-launcher.png"
        fi
      done
    done

    runHook postBuild
  '';

  inherit desktopItem;

  installPhase = ''
    runHook preBuild

    mkdir -p "$out/bin" "$out/libexec"
    substitute ${executable}/bin/ffxiv-benchmark-launcher "$out/bin/ffxiv-benchmark-launcher" \
      --subst-var-by launcher-path "$out"
    chmod a+x "$out/bin/ffxiv-benchmark-launcher"
    substitute ffxiv-benchmark.py "$out/libexec/ffxiv-benchmark.py" \
      --subst-var-by default-environment '${toString defaultEnvironment}' \
      --subst-var-by wine '${wine}/bin/wine64'

    shopt -s extglob
    mkdir -p "$out/share/icons/hicolor"
    cp -Rv {??,???}x{??,???}?(@2) "$out/share/icons/hicolor"
    ln -sv "${desktopItem}/share/applications" "$out/share/applications"

    runHook postBuild
  '';

  __structuredAttrs = true;

  meta = {
    description = "Unofficial benchmark for the critically acclaimed MMORPG Final Fantasy XIV. FINAL FANTASY is a registered trademark of Square Enix Holdings Co., Ltd.";
    homepage = "https://na.finalfantasyxiv.com/benchmark/";
    changelog = "https://na.finalfantasyxiv.com/lodestone/special/patchnote_log/";
    maintainers = [ lib.maintainers.reckenrode ];
    # Temporarily until it’s possible to allow unfree flake packages without impurities
    # license = lib.licenses.unfree;
    inherit (ffxiv.meta) platforms;
    hydraPlatforms = [ ];
  };
}
