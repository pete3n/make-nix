{ host }:

let
  flake = builtins.getFlake (toString ./.);
  hostConfig = flake.outputs.nixosConfigurations.${host};
in
builtins.attrNames (hostConfig.config.specialisation or { })
