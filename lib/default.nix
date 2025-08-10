{ lib, ... }:
rec {
  isPlatform = system: platform: lib.strings.hasSuffix ("-" + platform) system;
  isLinux = system: isPlatform system "linux";
  isDarwin = system: isPlatform system "darwin";

  mkHomeAlone = import ./home-alone.nix { inherit lib; };
}
