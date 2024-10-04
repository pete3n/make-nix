# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{ pkgs, ... }:
{
  dod-certs = pkgs.callPackage ./cross-platform/dod-certs { };
  angryoxide = pkgs.callPackage ./cross-platform/angryoxide { };
}
