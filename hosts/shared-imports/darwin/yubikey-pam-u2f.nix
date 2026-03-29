{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.pam_u2f ];

  environment.etc."pam.d/sudo".text = ''
    auth       sufficient     ${pkgs.pam_u2f}/lib/security/pam_u2f.so origin=pam://p22 appid=pam://p22 cue
    auth       sufficient     pam_tid.so
    auth       required       pam_opendirectory.so
    account    required       pam_permit.so
    password   required       pam_deny.so
    session    required       pam_permit.so
  '';
}
