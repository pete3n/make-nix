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
  sshPubKeys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIH0sKLi0IwMU62lLAEBiPudg4OxqQGY1n3MOsV8rAJybAAAAB3NzaDpwMjI= ssh:p22"
   ];
  piBoard = "rpi4";
  buildSystem = "x86_64-linux";
  deployMethod = "sd-image";
}
