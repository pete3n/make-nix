{
	backup = import ./cross-platform/backup.nix;
	battery-minder = import ./linux/battery-minder.nix;
	bootstrap-ssh = import ./cross-platform/bootstrap-ssh.nix;
  clip58 = import ./cross-platform/clip58.nix;
  lazydocker = import ./cross-platform/lazydocker.nix;
	power-profile-switcher = import ./linux/power-profile-switcher.nix;
	quick-notes = import ./cross-platform/quick-notes.nix;
  wallpaper-scripts = import ./cross-platform/wallpaper-scripts.nix;
}
