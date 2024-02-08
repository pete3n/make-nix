{pkgs, ...}: {
  users.users.pete = {
    isNormalUser = true;
    description = "pete";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [];
  };
}
