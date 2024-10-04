# Darwin only packages
{ pkgs, ... }:
{
  yubioath-darwin = pkgs.callPackage ./yubioath-darwin { };
}
