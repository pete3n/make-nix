{
  lib,
  stdenv,
  fetchzip,
}:
stdenv.mkDerivation rec {
  pname = "dod-certs";
  version = "10.2";

  src = fetchzip {
    url = "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-dod_approved_external_pkis_trust_chains.zip";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };

  installPhase = ''
    mkdir -p $out/dod-certs
    cp -r * $out/dod-certs
  '';

  meta = with lib; {
    description = "DoD Approved External PKIs Trust Chains version: ${version}";
    homepage = "https://public.cyber.mil/pki-pke/pkipke-document-library/";
    license = licenses.unfree;
    maintainers = with maintainers; [];
  };
}
