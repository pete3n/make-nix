{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "AngryOxide";
  version = "0.8.5";

  src = fetchFromGitHub {
    owner = "Ragnt";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-uVZ/tqN8Fw2P4Ue35jN8ZLodMIth6eZsJbgSsdbyqjE=";
  };

  cargoSha256 = "sha256-iBlAz9Bd3zD2wlm7oMEfeXxEoaE5ELH824gk0fmXajU=";

  meta = with lib; {
    description = "A 802.11 Attack tool built in Rust";
    homepage = "https://github.com/Ragnt/AngryOxide";
    license = licenses.mit;
    maintainers = with maintainers; [];
  };
}
