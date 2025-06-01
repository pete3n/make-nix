{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "angryoxide";
	version = "master";
  # Submodule is using ssh in this version which isn't accessible from Nix sandbox
	# 
	#  src = fetchFromGitHub {
	#    owner = "Ragnt";
	#    repo = pname;
	#    rev = "v${version}";
	#    hash = "";
	#		fetchSubmodules = true;
	#  };

  src = fetchFromGitHub { owner = "Ragnt";
    repo = pname;
    rev = "6eaaaf89ef0f2e9de7f6ba32533fdf2d28058f95"; # latest master commit
    fetchSubmodules = true;
    hash = "sha256-3xJmi8nQeHXeTSSu3/vg1SutaejRd7WhvKZKKDGUvIY="; # run build once to get real hash
  };
  cargoHash = "sha256-PcLwmC9EYi6SWaveIBT/9AQTh5mvpr6G4nkc+jcYDVM= ";

  meta = with lib; {
    description = "A 802.11 Attack tool built in Rust";
    homepage = "https://github.com/Ragnt/AngryOxide";
    license = licenses.mit;
    maintainers = with maintainers; [ "pete3n" ];
  };
}
