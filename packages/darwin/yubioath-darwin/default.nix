{ pkgs, ... }:
let
  version = "7.1.0";
in
pkgs.stdenv.mkDerivation rec {
  pname = "yubico-authenticator";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://developers.yubico.com/yubioath-flutter/Releases/yubico-authenticator-${version}-mac.dmg";
    sha256 = "sha256-kYaE51UY3Nf+AIcJWC64BAsG5DI7FbT6l5qrKplGcZo=";
  };

  buildInputs = [ pkgs.undmg ];
  sourceRoot = ".";
  phases = [
    "unpackPhase"
    "installPhase"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r "Yubico Authenticator.app" "$out/Applications/"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Yubico Authenticator for macOS";
    homepage = "https://developers.yubico.com/yubioath-flutter/Releases/";
    license = licenses.gpl3;
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ "pete3n" ];
  };
}
