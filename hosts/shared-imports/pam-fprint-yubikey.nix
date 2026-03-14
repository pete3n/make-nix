# Fingerprint or yubikey auth for laptops with SSH sudo support
{ config, pkgs, lib, makeNixAttrs, ... }:
let
  homeDir = config.users.users.${makeNixAttrs.user}.home or "/home/${makeNixAttrs.user}";
  u2f_keyfile = "${homeDir}/.config/Yubico/u2f_keys";
  authorized_keys = "${homeDir}/.ssh/authorized_keys";
  u2f = config.security.pam.u2f.settings;
in
{
  services.fprintd.enable = true;
	security.pam.sshAgentAuth.enable = true;

  security.pam.services.sudo = {
    u2fAuth    = lib.mkForce false;
    fprintAuth = lib.mkForce false;

    text = lib.mkForce ''
      # SSH session: authenticate via forwarded SSH agent key
      auth sufficient ${pkgs.pam_ssh_agent_auth}/lib/security/pam_ssh_agent_auth.so \
        file=${authorized_keys}

      # Factor: YubiKey U2F (preferred local)
      auth sufficient ${pkgs.pam_u2f}/lib/security/pam_u2f.so \
        cue \
        origin=${u2f.origin} \
        appid=${u2f.appid} \
        authfile=${u2f_keyfile} \
        openasuser \
        expand

      # Factor: fingerprint (fallback local)
      auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so max-tries=1 timeout=3

      # If none work, deny
      auth required ${pkgs.linux-pam}/lib/security/pam_deny.so

      account required ${pkgs.linux-pam}/lib/security/pam_unix.so
      session required ${pkgs.linux-pam}/lib/security/pam_unix.so
    '';
  };
}
