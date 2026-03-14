{
	backup = import ./cross-platform/backup.nix;
	hyprWhichKey = import ./linux/hyprWhichKey.nix;
	import-yubikey-ssh = import ./cross-platform/import-yubikey-ssh.nix;
	khal-notify = import ./linux/khal-notify.nix;
  lazydocker = import ./cross-platform/lazydocker.nix;
	p22Sync = import ./cross-platform/p22-sync.nix;
	pomodoro = import ./linux/pomodoro-module.nix;
	power-profile-switcher = import ./linux/power-profile-switcher.nix;
	quick-notes = import ./cross-platform/quick-notes.nix;
	yubi-age-secrets = import ./linux/yubi-age-secrets.nix;
  clip58 = import ./cross-platform/clip58.nix;
  wallpaper-scripts = import ./cross-platform/wallpaper-scripts.nix;
}
