# Customize pam for SSH server
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
  authorized_keys = "${homeDir}/.ssh/authorized_keys";
  u2f = config.security.pam.u2f.settings;
in
{
  security.pam.sshAgentAuth.enable = true;

  security.pam.services = {
    login.u2fAuth = lib.mkForce false;
    system-login.u2fAuth = lib.mkForce false;
    sudo = {
      u2fAuth = lib.mkForce false;
      fprintAuth = lib.mkForce false;
      text = lib.mkForce ''
        # SSH session: authenticate via forwarded SSH agent key
        auth sufficient ${pkgs.pam_ssh_agent_auth}/libexec/pam_ssh_agent_auth.so \
          file=${authorized_keys}
        # Local console sudo requires YubiKey
        auth required ${pkgs.pam_u2f}/lib/security/pam_u2f.so \
          cue \
          origin=${u2f.origin} \
          appid=${u2f.appid} \
          authfile=${u2f_keyfile} \
          openasuser \
          expand
        auth required ${pkgs.linux-pam}/lib/security/pam_unix.so try_first_pass
        account required ${pkgs.linux-pam}/lib/security/pam_unix.so
        session required ${pkgs.linux-pam}/lib/security/pam_unix.so
      '';
    };
  };
}
