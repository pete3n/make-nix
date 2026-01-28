{
	backup = import ./cross-platform/backup.nix;
	battery-minder = import ./linux/battery-minder.nix;
  clip58 = import ./cross-platform/clip58.nix;
	import-yubikey-ssh = import ./cross-platform/import-yubikey-ssh.nix;
  lazydocker = import ./cross-platform/lazydocker.nix;
	power-profile-switcher = import ./linux/power-profile-switcher.nix;
	quick-notes = import ./cross-platform/quick-notes.nix;
	yubi-age-secrets = import ./linux/yubi-age-secrets.nix;
  wallpaper-scripts = import ./cross-platform/wallpaper-scripts.nix;
}
