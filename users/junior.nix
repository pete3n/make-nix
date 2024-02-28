{pkgs, ...}: {
  users.users.junior = {
    isNormalUser = true;
    description = "junior";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [];
  };
}
