{
  lib,
  pkgs,
  makeNixAttrs,
  ...
}:
{
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
  ];

  virtualisation = {
    docker = {
      enable = lib.mkDefault false;
      rootless = {
        enable = lib.mkDefault true;
        setSocketVariable = lib.mkDefault true;
      };
    };
    libvirtd.enable = true;
  };

  users.users.${makeNixAttrs.user}.extraGroups = [
    "libvirtd"
  ];

  environment.systemPackages = [ pkgs.quickemu ];
  programs.virt-manager.enable = true;
}
