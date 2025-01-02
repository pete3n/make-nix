{
  stdenv,
  lib,
  fetchurl,
  perl,
  gnused,
  dpkg,
  makeWrapper,
  autoPatchelfHook,
  libredirect,
}:

stdenv.mkDerivation rec {
  pname = "cups-brother-hll3280cdw";
  version = "3.5.1";
  src = fetchurl {
    url = "https://download.brother.com/welcome/dlf105735/hll3280cdwpdrv-${version}-1.i386.deb";
    sha256 = "sha256-2JG7C+sC57f6+rKTWTjwnhvHrRp0qoFilQ/7KODNbr4=";
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    perl
    gnused
    libredirect
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
     runHook preInstall

     mkdir -p "$out"
     cp -pr opt "$out"
    # cp -pr usr/bin "$out/bin"
     rm "$out/opt/brother/Printers/hll3280cdw/cupswrapper/cupswrapperhll3280cdw"

     mkdir -p "$out/lib/cups/filter" "$out/share/cups/model"

     ln -s "$out/opt/brother/Printers/hll3280cdw/cupswrapper/brother_lpdwrapper_hll3280cdw" \
       "$out/lib/cups/filter/brother_lpdwrapper_hll3280cdw"
     ln -s "$out/opt/brother/Printers/hll3280cdw/cupswrapper/brother_hll3280cdw_printer_en.ppd" \
       "$out/share/cups/model/brother_hll3280cdw_printer_en.ppd"

     runHook postInstall
  '';

  # Fix global references and replace auto discovery mechanism
  # with hardcoded values.
  #
  # The configuration binary 'brprintconf_hll3280cdw' and lpd filter
  # 'brhll3280cdwfilter' has hardcoded /opt format strings.  There isn't
  # sufficient space in the binaries to substitute a path in the store, so use
  # libredirect to get it to see the correct path.  The configuration binary
  # also uses this format string to print configuration locations.  Here the
  # wrapper output is processed to point into the correct location in the
  # store.

  # TODO: Support for non x86_64
  postFixup = ''
    substituteInPlace $out/opt/brother/Printers/hll3280cdw/lpd/filter_hll3280cdw \
      --replace-warn "my \$BR_PRT_PATH =" "my \$BR_PRT_PATH = \"$out/opt/brother/Printers/hll3280cdw/\"; #" \
      --replace-warn "PRINTER =~" "PRINTER = \"hll3280cdw\"; #"

    substituteInPlace $out/opt/brother/Printers/hll3280cdw/cupswrapper/brother_lpdwrapper_hll3280cdw \
      --replace-warn "PRINTER =~" "PRINTER = \"hll3280cdw\"; #" \
      --replace-warn "my \$basedir = \`readlink \$0\`" "my \$basedir = \"$out/opt/brother/Printers/hll3280cdw/\""

    wrapProgram $out/opt/brother/Printers/hll3280cdw/lpd/x86_64/brprintconf_hll3280cdw \
      --set LD_PRELOAD "${libredirect}/lib/libredirect.so" \
      --set NIX_REDIRECTS /opt=$out/opt

    wrapProgram $out/opt/brother/Printers/hll3280cdw/lpd/x86_64/brhll3280cdwfilter \
      --set LD_PRELOAD "${libredirect}/lib/libredirect.so" \
      --set NIX_REDIRECTS /opt=$out/opt

    substituteInPlace $out/opt/brother/Printers/hll3280cdw/lpd/x86_64/brprintconf_hll3280cdw \
      --replace-warn \"\$"@"\" \"\$"@\" | LD_PRELOAD= ${gnused}/bin/sed -E '/^(function list :|resource file :).*/{s#/opt#$out/opt#}'"
  '';

  meta = with lib; {
    description = "Brother HL-L3280CDW printer driver";
    #license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ aplund ];
    platforms = [ "x86_64-linux" ];
    homepage = "http://www.brother.com/";
    downloadPage = "https://support.brother.com/g/b/downloadend.aspx?c=us&lang=en&prod=hll3280cdw_us_as&os=128&dlid=dlf105735_000&flang=4&type3=10283";
  };
}
