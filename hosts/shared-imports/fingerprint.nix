{
  config,
  pkgs,
  lib,
	makeNixAttrs,
  ...
}:

let
	homeDir = config.users.users.${makeNixAttrs.user}.home or "/home/${makeNixAttrs.user}";
	u2f_keyfile = "${homeDir}/.config/Yubico/u2f_keys";
  u2f = config.security.pam.u2f.settings;
in
{
  services.fprintd.enable = true;
  security.pam.services = {
    sudo.u2fAuth = lib.mkForce false;

    # Password + (fingerprint OR U2F)
    sudo.text = lib.mkForce ''
      # Factor 1: password (always required)
      auth required pam_unix.so try_first_pass

      # Factor 2 preferred: YubiKey U2F
      auth sufficient ${pkgs.pam_u2f}/lib/security/pam_u2f.so \
        cue \
        origin=${u2f.origin} \
        appid=${u2f.appid} \
        authfile=${u2f_keyfile} \
        openasuser \
        expand

      # Factor 2 fallback: fingerprint
      auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so max-tries=1 timeout=3

      auth required pam_deny.so

      account required pam_unix.so
      session required pam_unix.so
    '';
  };
}
