{ pkgs, ... }:
{
  users.users.eco = {
    isNormalUser = true;
    description = "eco";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [ ];
  };
}
