{...}: {
  users.users.pete = {
    isNormalUser = true;
    description = "pete";
    extraGroups = ["networkmanager" "wheel" "docker"];
  };
}
