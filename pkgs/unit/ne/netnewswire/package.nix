# SPDX-License-Identifier: MIT

{ lib
, fetchurl
, stdenv
, unzip
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "netnewswire";
  version = "6.1";

  src = fetchurl {
    url = "https://github.com/Ranchero-Software/NetNewsWire/releases/download/mac-${finalAttrs.version}/NetNewsWire${finalAttrs.version}.zip";
    hash = "sha256-kWj8H3o0C977joZpMT1/lmnBPV9VBNffEWlE27uPf2k=";
  };

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/Applications
    cp -R ../*.app $out/Applications
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
