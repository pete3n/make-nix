{ pkgs, config, build_target, ... }:
###################################################################################
#
#  macOS's System configuration
#
#  All the configuration options are documented here:
#    https://nix-darwin.github.io/nix-darwin/manual
#
###################################################################################
{
  system = {
    stateVersion = 5;
    activationScripts.activateSettings = {
      text = ''
        if [ -n "${config.system.primaryUser}" ]; then
          sudo -u ${config.system.primaryUser} \
            /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
        fi
      '';
    };

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
  security.pam.services.sudo_local.touchIdAuth = false;

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
  };

  time.timeZone = "America/New_York";

  fonts.packages = [
		pkgs.nerd-fonts.jetbrains-mono
  ];
}
