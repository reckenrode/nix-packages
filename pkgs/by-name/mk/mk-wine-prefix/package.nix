{ lib, gnused, wine64, stdenvNoCC }:

{
  name ? "wine-prefix",
  extras ? {
    files = [ ];
    buildPhase = "";
  },
  wine ? wine64,
}:

let
  inherit (lib) concatStringsSep flatten mapAttrsToList;

  copyFiles =
    targetPath:
    map (sourcePath: ''
      targetPath="$WINEPREFIX/drive_c/${targetPath}"
      mkdir -p "$targetPath"
      for file in "${sourcePath}"/*; do
        rm -f "$targetPath/$(basename "$file")"
        ln -s "$(readlink -f "$file")" "$targetPath"
      done
    '');

  buildPhaseScripts = flatten ((mapAttrsToList copyFiles extras.files) ++ [ extras.buildPhase ]);
  extraBuildPhase = concatStringsSep "\n" buildPhaseScripts;
in
stdenvNoCC.mkDerivation {
  inherit name;

  strictDeps = true;

  buildInputs = [ wine ];

  dontUnpack = true;
  dontConfigure = true;

  # If sandboxing is set to relaxed, `wineboot` will fail unless it’s allowed these things.
  sandboxProfile = lib.optionalString stdenvNoCC.isDarwin ''
    (allow file-read-data (path-literal "/Library/Preferences/.GlobalPreferences.plist"))
    (allow mach-lookup mach-register (global-name-regex #"^/tmp/.wine-[A-Z0-9]*/.*$"))
  '';

  buildPhase =
    ''
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
      wine64 reg delete 'HKLM\Software\Microsoft\Cryptography' /v MachineGuid /f

      wine64 reg delete 'HKCU\Environment' /f
      wine64 reg delete 'HKCU\Volatile Environment' /f
      wine64 reg delete 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' /f

      wineserver -k SIGTERM

      # Force wine-mono and wine-gecko to have consistent MSI filenames.
      declare -a installedPkgs=(
        $(grep InstallProperties prefix/system.reg | sed 's/^\[\([^]]*\)\].*$/\1/;s|\\\\|\\|g;s|^|HKLM\\|')
      )
      for key in "''${installedPkgs[@]}"; do
        msipath=$(
          wine64 reg query "$key" /v LocalPackage \
          | tail -n 2 | cut -c31- | head -n 1 | sed -e s/$'\r'//';s/C:\\//;s|\\|/|g' || true
        )
        if [ -n "$msipath" ]; then
          read x
          stable_filename="$x$x$x$x.msi"
          mv "prefix/drive_c/$msipath" "prefix/drive_c/windows/Installer/$stable_filename"
          wine64 reg add "$key" /v 'LocalPackage' /d 'C:\windows\Installer\'"$stable_filename" /f
        fi
      done < <(echo {a..z} | tr ' ' '\n')
    ''
    + extraBuildPhase
    + ''
      wineserver -k SIGTERM

      # Set the modification time to the UNIX epoch, so the value is consistent between builds.
      # See https://devblogs.microsoft.com/oldnewthing/20220602-00/?p=106706 for the magic number.
      for regfile in user.reg system.reg; do
        sed -E '
          s/^(\[.*\]) [[:digit:]]+$/\1 0/;
          s/^#time=.*$/#time=19db1ded53e8000/;
          s/^"InstallDate"="[[:digit:]]+"$/"InstallDate"="19700101"/;
          s/^"InstallDate"=dword:[[:xdigit:]]+$/"InstallDate"=dword:00000000/;
          s/^"FirstInstallDateTime"=hex:.*$/"FirstInstallDateTime"=hex:0,0,0,0/;
          s/^"DriverDate"="[[:digit:]]+-[[:digit:]]+-[[:digit:]]+"$/"DriverDate"="1-1-1970"/;
          s/^"DriverDateData"=hex:.*$/"DriveDateData"=hex:1,9d,b1,de,d5,3e,80,00/;
        ' -i "prefix/$regfile"
      done

      rm -rf prefix/drive_c/users
    '';

  __structuredAttrs = true;

  installPhase = ''
    mkdir -p "$out"

    cp -R prefix/drive_c "$out"

    cp prefix/system.reg "$out"
    cp prefix/user.reg "$out"
  '';
}
