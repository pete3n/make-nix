{
  lib,
  pkgs,
  outputs,
  make_opts,
  ...
}:

let
  availableSpecialisations = [
    "x11"
    "x11_egpu"
    "wayland"
    "wayland_egpu"
  ];

  availableSpecs = builtins.filter (
    name: builtins.elem name availableSpecialisations
  ) make_opts.specialisations;

  specMap = {
    x11 = import ./specialisations/x11.nix { inherit lib pkgs outputs; };
    x11_egpu = import ./specialisations/x11_egpu.nix { inherit lib pkgs outputs; };
    wayland = import ./specialisations/wayland.nix { inherit lib pkgs outputs; };
    wayland_egpu = import ./specialisations/wayland_egpu.nix { inherit lib pkgs outputs; };
  };

in
{
  config = {
    specialisation = lib.genAttrs availableSpecs (specName: specMap.${specName});
  };
}
