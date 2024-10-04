{ pkgs, build_target, ... }:
###################################################################################
#
#  macOS's System configuration
#
#  All the configuration options are documented here:
#    https://daiderd.com/nix-darwin/manual/index.html#sec-options
#
###################################################################################
{
  system = {
    stateVersion = 5;
    # activationScripts are executed every time you boot the system or run `nixos-rebuild` / `darwin-rebuild`.
    activationScripts.postUserActivation.text = ''
      # activateSettings -u will reload the settings from the database and apply them to the current session,
      # so we do not need to logout and login again to make the changes take effect.
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    defaults = {
      menuExtraClock.Show24Hour = true;
      dock.autohide = true;
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 14;
        KeyRepeat = 1;
      };
    };

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = false;
      remapCapsLockToEscape = false;

      # match common keyboard layout: 'ctrl | command | alt'
      swapLeftCommandAndLeftAlt = false;
    };
  };

  networking.hostName = "${build_target.host}";
  networking.computerName = "${build_target.host}";
  system.defaults.smb.NetBIOSName = "${build_target.host}";

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = false;

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs = {
    zsh = {
      enable = true;
      enableCompletion = false; # Disabled because
      # Otherwise it breaks home-manager zsh completions
      # https://discourse.nixos.org/t/zsh-compinit-warning-on-every-shell-session/22735/4
    };
  };

  environment = {
    shells = with pkgs; [
      bash
      zsh
    ];
    loginShell = pkgs.zsh;
  };

  time.timeZone = "America/New_York";

  fonts = {
    packages = with pkgs; [ (nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) ];
  };
}
