{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    opensc
    pam_u2f
    pamtester
    pinentry-curses
    yubico-pam
    yubikey-manager
    yubioath-flutter
    yubikey-personalization
  ];
  services = {
    pcscd.enable = true; # Enable smart card daemon
    udev.packages = [ pkgs.yubikey-personalization ];
  };
  programs.gnupg.agent.enable = true;

  # Configure u2f Yubikeys with:
  # mkdir -p ~/.config/Yubico
  # pamu2fcfg > ~/.config/Yubico/u2f_keys
  # pamu2fcfg -n >> ~/.config/Yubico/u2f_keys (For additional keys)
  # WARNING: Don't set these to true until keys are configured:
  security.pam = {
    services = {
      login.u2fAuth = false;
      sudo.u2fAuth = true;
    };
    u2f = {
      enable = true;
      control = "required";
      settings = {
        debug = false;
        cue = true;
      };
    };
  };
  # TODO: Test pam configuration before logging out with:
  # pamtester login <username> authenticate
  # pamtester sudo <username> authenticate
}
