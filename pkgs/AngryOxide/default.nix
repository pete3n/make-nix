{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "AngryOxide";
  version = "0.8.28";

  src = fetchFromGitHub {
    owner = "Ragnt";
    repo = pname;
    rev = "v${version}";
    sha256 = "";
  };

  cargoSha256 = "";

  meta = with lib; {
    description = "A 802.11 Attack tool built in Rust";
    homepage = "https://github.com/Ragnt/AngryOxide";
    license = licenses.mit;
    maintainers = with maintainers; [];
  };
}
