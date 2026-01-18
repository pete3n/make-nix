# Common u2f parameters shared by all systems
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    opensc
    pinentry-curses
    pam_u2f
    pamtester
    yubioath-flutter
    yubikey-manager
    yubikey-personalization
  ];

  programs.gnupg.agent.enable = true;

  services = {
    pcscd.enable = true;
    udev.packages = [ pkgs.yubikey-personalization ];
  };

  security.pam.u2f = {
    enable = true;

    settings = {
      origin = "pam://p22";
      appid  = "pam://p22";
      cue    = true;
      debug  = false;
    };
  };
}
