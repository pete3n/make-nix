{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    opensc
    pam_u2f
    pamtester
    pinentry
    yubico-pam
    yubikey-manager
    yubikey-manager-qt
    yubioath-flutter
    yubikey-personalization
    yubikey-personalization-gui
  ];
  services.pcscd.enable = true; # Enable smart card daemon
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
      authFile = pkgs.writeText "u2f-auth-file" ''
        pete:9b6Ief9xM0RgX7A2RoVNAGoJ7F3SaW0/TK3eiZ78nWLi/QMStqVXiwqhRdlC+X21jGdLc/UbVBKtWPhvjhG6MQ==,6Dm35/cYicr4QKEji/MquVU6SCmjjw66BzRanp5nzACzzXRyXTbwApV08oC4pIwB/Fx5BVxbmgIWel/z4CV/AA==,es256,+presencepete:eASVCOywAZZasf1zw9BV5fB87fbZx1gK6qb/Y6BE3dvVJdQt5ZzsQtKMiH5MY0AjXUtvW7DEAFDqDOwJiGIJlg==,g1C3ME7/WXqiL2s7S3BrIRk+J3u6WWUF8wl6ff1/srVbh39UGIKEB1nKeQfz9ZtqvD9AkPhee/CeJ40chayl2g==,es256,+presence
      '';
    };
  };

  # TODO: Test pam configuration before logging out with:
  # pamtester login <username> authenticate
  # pamtestr sudo <username> authenticate
}
