{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.pam_u2f ];

  security.pam.services.sudo_local.text = ''
    auth       sufficient     ${pkgs.pam_u2f}/lib/security/pam_u2f.so origin=pam://p22 appid=pam://p22 cue
  '';
}
