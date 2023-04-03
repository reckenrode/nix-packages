# SPDX-License-Identifier: MIT

{ lib
, fetchurl
, stdenvNoCC
, unzip
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "daisydisk";
  version = "4.24";

  src = fetchurl {
    url = "https://web.archive.org/web/20230326094956/https://daisydiskapp.com/download/DaisyDisk.zip";
    hash = "sha256-UWkJ8teqpFBcvU0UujCxLzyQ3bGwC9Zbsh5xWCyQFcc=";
  };

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/Applications
    cp -R ../*.app $out/Applications
  '';

  meta = {
    description = ''
      Find out what’s taking up your disk space and recover it in the most efficient and easy way.
    '';
    homepage = "https://daisydiskapp.com";
    changelog = "https://daisydiskapp.com/releases";
    # Temporarily until it’s possible to allow unfree flake packages without impurities
    # license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
  };
})
