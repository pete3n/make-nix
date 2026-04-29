# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{ pkgs, ... }:
{
  ipod-shuffle-4g = import ./ipod-shuffle-4g { inherit pkgs; };
	vip-access = import ./vipaccess { inherit pkgs; };
}
