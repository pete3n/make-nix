# Linux only packages
{ pkgs, ... }:
{
  cups-brother-hll3280cdw = pkgs.callPackage ./cups-brother-hll3280cdw { };
}
