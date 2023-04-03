# SPDX-License-Identifier: MIT

{ lib
, fetchurl
, stdenvNoCC
, undmg
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "steam-mac";
  version = "2023.03.05+23.33.30";

  src = fetchurl {
    url = "https://web.archive.org/web/${lib.replaceStrings [ "." "+" ] [ "" "" ] finalAttrs.version}/https://cdn.cloudflare.steamstatic.com/client/installer/steam.dmg";
    hash = "sha256-X1VnDJGv02A6ihDYKhedqQdE/KmPAQZkeJHudA6oS6M=";
  };

  buildInputs = [ undmg ];

  unpackPhase = ''
    undmg $src
  '';

  installPhase = ''
    mkdir -p $out/Applications
    cp -r *.app $out/Applications
  '';

  meta = {
    description = ''
      Steam is the ultimate destination for playing, discussing, and creating games.
    '';
    homepage = "https://steampowered.com";
    # license = lib.licenses.unfree;
    platforms = [ "x86_64-darwin" ];
  };
})
