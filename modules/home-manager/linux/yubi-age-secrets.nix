{ config, lib, ... }:
let
  cfg = config.programs.yubi-age-secrets;

  wifiFiles =
    lib.mapAttrs' (name: path: {
      name = "wpa_supplicant/${name}.conf.age";
      value = { source = path; };
    }) cfg.wifiProfiles;
in
{
  options.programs.yubi-age-secrets = {
    enable = lib.mkEnableOption "Install per-user AGE/YubiKey identity refs and encrypted profiles into XDG config.";

    identityFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing age-plugin-yubikey identity stanzas.";
    };

    wifiProfiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
      description = "profileName -> path-to-*.conf.age to install under ~/.config/wpa_supplicant/<name>.conf.age";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = lib.mkMerge [
      (lib.optionalAttrs (cfg.identityFile != null) {
        "age/age-plugin-yubikeys" = { source = cfg.identityFile; };
      })
      wifiFiles
    ];
  };
}
