# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{pkgs, ...}: {
  dod-certs = pkgs.callPackage ./dod-certs {};
  AngryOxide = pkgs.callPackage ./AngryOxide {};
  yubioath-darwin = pkgs.callPackage ./yubioath-darwin {};
}
