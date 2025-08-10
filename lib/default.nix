{ lib, ... }:
rec {
  isPlatform = system: platform: lib.strings.hasSuffix ("-" + platform) system;
  isLinux = system: isPlatform system "linux";
  isDarwin = system: isPlatform system "darwin";

  getHomeAloneAttrs = import ./home-alone.nix { inherit lib; };
  getHomeAlonePath = import ./home-path.nix { inherit lib; };
}
