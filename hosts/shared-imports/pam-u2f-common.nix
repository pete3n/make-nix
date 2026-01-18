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

    # Don't rely on this "control" for sudo since we'll write explicit sudo.text
    control = "required";

    settings = {
      origin = "pam://p22";
      appid = "pam://p22";
      cue = true;
      debug = false;

      # Use the same path everywhere
      authFile = "%h/.config/Yubico/u2f_keys";

      openasuser = true;
      expand = true;
    };
  };
}
