{ config, ... }:
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
}
