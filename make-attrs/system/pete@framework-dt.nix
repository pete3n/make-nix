{ ... }:
{
  user = "pete";
  host = "framework-dt";
  system = "x86_64-linux";
  isLinux = true;
  isHomeAlone = false;
  useHomebrew = false;
  useCache = false;
  useKeys = false;
  tags = [ "crypto" "cuda" "gaming" "git-ssh-user" "hyprland" "laptop" "local-ai" "media-creation" "messaging" "mpd" "nixvim" "office" "p22" "power-user" "ssh-user" "yubi-age-user" "yubi-ssh-import" "yubi-u2f" ];
  specialisations = [ "wayland" "wayland_egpu" ];
  sshPubKeys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIH0sKLi0IwMU62lLAEBiPudg4OxqQGY1n3MOsV8rAJybAAAAB3NzaDpwMjI= ssh:p22"
   ];
}
