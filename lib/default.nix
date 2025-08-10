{ lib, ... }:
rec {
  isPlatform = system: platform: lib.strings.hasSuffix ("-" + platform) system;
  isLinux = system: isPlatform system "linux";
  isDarwin = system: isPlatform system "darwin";

  getHomeAttrs = import ./home-attrs.nix { inherit lib; };
  getHomePath = import ./home-path.nix { inherit lib; };
}
