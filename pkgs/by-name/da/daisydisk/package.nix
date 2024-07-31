# SPDX-License-Identifier: MIT

{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "daisydisk";
  version = "4.25";

  src = fetchurl {
    url = "https://daisydiskapp.com/download/DaisyDisk_${
      lib.replaceStrings [ "." ] [ "_" ] finalAttrs.version
    }.zip";
    hash = "sha256-+e2Xd2f9oDxZ5D1y8S5VQyIugnmWFAgkQkh0nwW3C8A=";
  };

  nativeBuildInputs = [ unzip ];

  dontFixup = true;

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
