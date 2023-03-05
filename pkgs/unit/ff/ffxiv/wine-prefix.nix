{ stdenvNoCC
, lib
}:

{ name ? "wine-prefix"
, extras ? { }
, wine
}:

let
  copyFiles = targetPath: map (sourcePath: ''
    targetPath="$out/drive_c/${targetPath}"
    mkdir -p "$targetPath"
    for file in "${sourcePath}"/*; do
      cp -R "$file" "$targetPath"
    done
  '');
in
stdenvNoCC.mkDerivation {
  inherit name;

  buildInputs = [ wine ];

  dontUnpack = true;
  dontConfigure = true;

  # If sandboxing is set to relaxed, `wineboot` will fail unless it’s allowed these things.
  sandboxProfile = lib.optionalString stdenvNoCC.isDarwin ''
    (allow file-read-data (path-literal "/Library/Preferences/.GlobalPreferences.plist"))
    (allow mach-lookup mach-register (global-name-regex #"^/tmp/.wine-[A-Z0-9]*/.*$"))
  '';

  buildPhase = ''
    WINEPREFIX="$(pwd)/prefix" WINEDEBUG=-all
    export WINEPREFIX WINEDEBUG

    mkdir -p "$(pwd)/prefix"

    wineboot --init
    wine64 msiexec /i ${wine}/share/wine/gecko/wine-gecko-*-x86_64.msi
    wineserver --kill

    rm -rf prefix/drive_c/users
  '';

  installPhase = ''
    mkdir -p "$out"
    cp -R prefix/drive_c "$out"
    cp prefix/*.reg "$out"
  '' + lib.concatStringsSep "\n" (lib.flatten (lib.mapAttrsToList copyFiles extras));
}
