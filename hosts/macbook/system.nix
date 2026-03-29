# MacOS System configuration options
# All the configuration options are documented here:
# https://nix-darwin.github.io/nix-darwin/manual
{
  config,
  lib,
  makeNixAttrs,
  makeNixLib,
  ...
}:
let
  makeTags = makeNixAttrs.tags;
  hasTag = makeNixLib.hasTag;
in
{
  system = {
    stateVersion = 5;
    activationScripts = {
      preActivation.text = ''
        ${lib.optionalString (hasTag "p22" makeTags) # sh
          ''
            if [ -f /etc/auto_master ]; then
            	echo "Backing up /etc/auto_master to /etc/auto_master.before-nix-darwin"
            	mv /etc/auto_master /etc/auto_master.before-nix-darwin
            fi
          ''
        }
      '';
      activateSettings = {
        text = # sh
          ''
            if [ -n "${config.system.primaryUser}" ]; then
            	sudo -u ${config.system.primaryUser} \
            		/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
            fi
          '';
      };
    };
    primaryUser = makeNixAttrs.user;

    defaults = {
      menuExtraClock.Show24Hour = true;
      dock.autohide = true;
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 14;
        KeyRepeat = 1;
      };
      smb.NetBIOSName = "${makeNixAttrs.host}";
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
