{ build_target, ... }:

let
  crossPlatformModules = import ./cross-platform/default.nix;
  linuxModules = if build_target.isLinux then import ./linux/default.nix else [ ];
  darwinModules = if !build_target.isLinux then import ./darwin/default.nix else [ ];
in
crossPlatformModules ++ linuxModules ++ darwinModules
