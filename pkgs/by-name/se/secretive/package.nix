# SPDX-License-Identifier: MIT

{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  gitUpdater,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "secretive";
  version = "2.3.1";

  src = fetchurl {
    url = "https://github.com/maxgoedjen/secretive/releases/download/v${finalAttrs.version}/Secretive.zip";
    hash = "sha256-STpyNiiYtEgLqnDxFdlRW0Gyr0pQPK8AJ34rw4JLC70=";
  };

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/Applications
    cp -R ../*.app $out/Applications
  '';

  passthru.updateScript = gitUpdater { rev-prefix = "v"; };

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
