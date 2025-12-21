{ config, pkgs, lib, ... }:
{
	services.fprintd.enable = true;

	security.pam.services.sudo.text = lib.mkForce ''
		auth required pam_unix.so try_first_pass
		auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so
		auth sufficient ${pkgs.pam_u2f}/lib/security/pam_u2f.so \
     cue origin=${config.security.pam.u2f.settings.origin} \
      appid=${config.security.pam.u2f.settings.appid} \
      authfile=${config.security.pam.u2f.settings.authFile} \
      openasuser

    auth required pam_deny.so

    account required pam_unix.so
    session required pam_unix.so
	'';
}
