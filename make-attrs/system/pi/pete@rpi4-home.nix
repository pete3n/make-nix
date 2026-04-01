{ ... }:
{
  user = "pete";
  host = "rpi4-home";
  system = "aarch64-linux";
  isLinux = true;
  isHomeAlone = false;
  useHomebrew = false;
  useCache = true;
  useKeys = true;
  tags = [ "ssh-user" "sudo-user" "git" ];
  specialisations = [ ];
  sshPubKeys = [ ];
  piBoard = "rpi4";
  buildSystem = "x86_64-linux";
  deployMethod = "sd-image";
}
