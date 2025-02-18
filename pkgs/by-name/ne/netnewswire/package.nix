# SPDX-License-Identifier: MIT

{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "netnewswire";
  version = "6.1.9";

  src = fetchurl {
    url = "https://github.com/Ranchero-Software/NetNewsWire/releases/download/mac-${finalAttrs.version}/NetNewsWire${finalAttrs.version}.zip";
    hash = "sha256-wG1/EpsK1CMXDTM/WlNFBBUVq6IUSj0GEkqY5Azf/ls=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/Applications
    cp -R *.app $out/Applications
  '';

  meta = {
    description = ''
      It’s a free and open source feed reader for macOS and iOS.

      It supports RSS, Atom, JSON Feed, and RSS-in-JSON formats.

      More info: https://ranchero.com/netnewswire/
    '';
    homepage = "https://netnewswire.com";
    changelog = "https://github.com/Ranchero-Software/NetNewsWire/releases";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
})
