{
  lib,
  stdenv,
  fetchzip,
}:
stdenv.mkDerivation rec {
  pname = "dod-certs";
  version = "11.0";

  src = fetchzip {
    url = "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-dod_approved_external_pkis_trust_chains.zip";
    sha256 = "sha256-sUMi+ZCLmqt5XgqNmDTLlP/9mdgH+x4Zjv+ijG10PXU=";
  };

  installPhase = ''
    mkdir -p $out/dod-certs
    cp -r * $out/dod-certs
  '';

  meta = with lib; {
    description = "DoD Approved External PKIs Trust Chains version: ${version}";
    homepage = "https://public.cyber.mil/pki-pke/pkipke-document-library/";
    #license = licenses.unfree; # This seems broken for some reason
    maintainers = with maintainers; [];
  };
}
