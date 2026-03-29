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
        ${lib.optionalString (hasTag "p22" makeTags) ''
          for f in /etc/auto_master; do
            if [ -f "$f" ] && [ ! -f "$f.before-nix-darwin" ]; then
              echo "Backing up $f to $f.before-nix-darwin"
              mv "$f" "$f.before-nix-darwin"
            fi
          done
        ''}
        ${lib.optionalString (hasTag "yubi-u2f" makeTags) ''
          for f in /etc/pam.d/sudo; do
            if [ -f "$f" ] && [ ! -f "$f.before-nix-darwin" ]; then
              echo "Backing up $f to $f.before-nix-darwin"
              mv "$f" "$f.before-nix-darwin"
            fi
          done
        ''}
      '';
      activateSettings = {
        text = ''
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
