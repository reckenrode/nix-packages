{ stdenvNoCC
, lib
}:

{ name ? "wine-prefix"
, extras ? { }
, wine
}:

let
  copyFiles = targetPath: map (sourcePath: ''
    targetPath="prefix/drive_c/${targetPath}"
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

    mkdir -p "$WINEPREFIX"

    wineboot --init
    wine64 msiexec /i ${wine}/share/wine/gecko/wine-gecko-*-x86_64.msi

    # Remove impurities from `system.reg` and `user.reg`
    wine64 reg add 'HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' \
      /v 'Common Favorites' /d 'C:\users\Public\Favorites' /f
    wine64 reg delete 'HKLM\System\CurrentControlSet\Control\ComputerName\ComputerName' /f
    wine64 reg delete 'HKLM\System\CurrentControlSet\Services\Tcpip\Parameters' \
      /v 'Hostname' /f
    wine64 reg delete 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-21-0-0-0-1000' \
      /v 'ProfileImagePath' /f

    wine64 reg delete 'HKCU\Environment' /f
    wine64 reg delete 'HKCU\Volatile Environment' /f
    wine64 reg delete 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' /f

    wineserver --kill

    rm -rf prefix/drive_c/users
  '' + lib.concatStringsSep "\n" (lib.flatten (lib.mapAttrsToList copyFiles extras));

  installPhase = ''
    mkdir -p "$out"

    cp -R prefix/drive_c "$out"

    cp prefix/system.reg "$out"
    cp prefix/user.reg "$out"
  '';
}
