{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "angryoxide";
  version = "0.8.28";

  src = fetchFromGitHub {
    owner = "Ragnt";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-n2c1G8Y9dFV+0MZehCRBAKkzN6XOWfDX0AVWb+o08VI=";
  };

  cargoSha256 = "sha256-cir3UNHE7z+pq3oBdBo8U9tcRh6jCCSN/bwuDTg5rrw=";

  meta = with lib; {
    description = "A 802.11 Attack tool built in Rust";
    homepage = "https://github.com/Ragnt/AngryOxide";
    license = licenses.mit;
    maintainers = with maintainers; [ "pete3n" ];
  };
}
