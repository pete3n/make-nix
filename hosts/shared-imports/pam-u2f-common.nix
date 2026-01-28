# Common u2f parameters shared by all systems
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
		age
		age-plugin-yubikey
    opensc
    pam_u2f
    pamtester
    pinentry-curses
    yubikey-manager
    yubikey-personalization
    yubioath-flutter
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
