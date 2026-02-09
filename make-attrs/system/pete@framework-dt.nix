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
  tags = [ "poweruser" "hyprland" "sshuser" ];
	sshPubKeys = [ 
		"sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIH0sKLi0IwMU62lLAEBiPudg4OxqQGY1n3MOsV8rAJybAAAAB3NzaDpwMjI= ssh:p22"
	];
  specialisations = [ "wayland" "wayland_egpu" ];
}
