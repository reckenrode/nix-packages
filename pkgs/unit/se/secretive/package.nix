# SPDX-License-Identifier: MIT

{ lib
, fetchurl
, stdenvNoCC
, unzip
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "secretive";
  version = "2.3.0";

  src = fetchurl {
    url = "https://github.com/maxgoedjen/secretive/releases/download/v${finalAttrs.version}/Secretive.zip";
    hash = "sha256-X8+54irgX6YZcbfFcIn3DTbRZz4A3TlePoWeWFISgqY=";
  };

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/Applications
    cp -R ../*.app $out/Applications
  '';

  meta = {
    description = ''
      Secretive is an app for storing and managing SSH keys in the Secure Enclave. It is inspired by
      the sekey project, but rewritten in Swift with no external dependencies and with a handy
      native management app.
    '';
    homepage = "https://github.com/maxgoedjen/secretive";
    changelog = "https://github.com/maxgoedjen/secretive/releases";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
})
