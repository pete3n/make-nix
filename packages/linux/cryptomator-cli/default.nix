{ lib, stdenv, fetchFromGitHub, maven, jdk21, makeWrapper, coreutils }:

stdenv.mkDerivation rec {
  pname = "cryptomator-cli";
  version = "0.6.2";

  src = fetchFromGitHub {
    owner = "cryptomator";
    repo = "cryptomator-cli";
    rev = "v${version}";
    hash = "";
  };

  nativeBuildInputs = [ maven jdk21 makeWrapper coreutils ];

  # Required for jlink and jpackage execution
  JAVA_HOME = "${jdk21}";

  buildPhase = ''
    echo "Building Java app with Maven..."
    mvn -B clean package

    mkdir -p target/mods
    cp ./LICENSE.txt ./target/
    mv ./target/${pname}-*.jar ./target/mods
  '';

  installPhase = ''
    echo "Creating runtime image with jlink..."
    substitute dist/jlink.args target/jlink.args \
      --subst-var JAVA_HOME --subst-var APP_VERSION

    ${jdk21}/bin/jlink @target/jlink.args

    echo "Packaging CLI app with jpackage..."
    substitute dist/jpackage.args target/jpackage.args \
      --subst-var JAVA_HOME --subst-var JP_APP_VERSION \
      --subst-var NATIVE_ACCESS_PACKAGE

    ${jdk21}/bin/jpackage @target/jpackage.args

    mkdir -p $out/bin
    cp -r target/cryptomator-cli/* $out/
    ln -s $out/bin/cryptomator-cli $out/bin/${pname}
  '';

  # FUSE package name will depend on target arch
  NATIVE_ACCESS_PACKAGE = lib.optionalString (stdenv.hostPlatform.system == "x86_64-linux")
    "org.cryptomator.jfuse.linux.amd64";

  APP_VERSION = version;
  JP_APP_VERSION = "99.9.9";

  meta = with lib; {
    description = "Cryptomator CLI interface";
    homepage = "https://github.com/cryptomator/cryptomator-cli";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ pete3n ];
    platforms = platforms.linux;
  };
}

