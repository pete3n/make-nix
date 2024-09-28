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
    sha256 = "sha256-n2c1G8Y9dFV+0MZehCRBAKkzN6XOWfDX0AVWb+o08VI=";
  };

  cargoSha256 = "sha256-SdhiCMN+rUws1P8wpkp5x7JlXaA1cmSmPjfQXgeFI4k=";

  meta = with lib; {
    description = "A 802.11 Attack tool built in Rust";
    homepage = "https://github.com/Ragnt/AngryOxide";
    license = licenses.mit;
    maintainers = with maintainers; ["pete3n"];
  };
}
