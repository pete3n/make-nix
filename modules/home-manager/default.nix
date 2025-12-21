{
  wallpaper-scripts = import ./cross-platform/wallpaper-scripts.nix;
  lazydocker = import ./cross-platform/lazydocker.nix;
  clip58 = import ./cross-platform/clip58.nix;
	backup = import ./cross-platform/backup.nix;
	battery-minder = import ./linux/battery-minder.nix;
	power-profile-switcher = import ./linux/power-profile-switcher.nix;
	quickNotes = import ./cross-platform/quick_notes.nix;
}
