{
  backup = import ./cross-platform/backup.nix;
  clip58 = import ./cross-platform/clip58.nix;
	fzf-launcher = import ./darwin/fzf-launcher.nix;
  hyprWhichKey = import ./linux/hyprWhichKey.nix;
  khal-notify = import ./linux/khal-notify.nix;
  lazydocker = import ./cross-platform/lazydocker.nix;
  p22Sync = import ./cross-platform/p22-sync.nix;
  pomodoro = import ./linux/pomodoro-module.nix;
  power-profile-switcher = import ./linux/power-profile-switcher.nix;
  quick-notes = import ./cross-platform/quick-notes.nix;
  wallpaper-scripts = import ./cross-platform/wallpaper-scripts.nix;
  yubi-age-secrets = import ./linux/yubi-age-secrets.nix;
  yubi-age-decrypt = import ./cross-platform/yubi-age-decrypt.nix;
  yubi-ssh-import = import ./cross-platform/yubi-ssh-import.nix;
	zoeyChar = import ./linux/zoey-char.nix;
}
