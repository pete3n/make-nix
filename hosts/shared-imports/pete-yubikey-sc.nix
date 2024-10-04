{ pkgs, ... }:
{
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
      debug = false;
      cue = true;
      control = "required";
      authFile = pkgs.writeText "pete-u2f-auth-file" ''
        pete:VitP/URTordhG7xWAtVoFFxZOiK8L2cUoBY9SXWROS3vWdhL6rZYm+biNYqMmvwBz0I4O09IhUVnILsdBg/P+Q==,/Jk3pOd5nUrIiVzVMHRtJ+HxS8UBkjz1BTV7zXvwRf/0tKqfEhhR8EnsZbsrD0daw4oXDwi04RWiZJS38p/6xw==,es256,+presence:+GB7k/U1qVNeiy6c6Y6jmIiY3GZRmL8KNkersUZiCLmIfS0AShb3K++7s2Lzv7Xmz594RKPuHJ1XFS7FyLH+Cg==,NWUx6LrmdphmF0m6LVnKYhsndPprfe8x3OhqCUQ06tllGoJBm694fhJ6RvTQiXSJ4fF2GqIC5LRffPQnWzG8fw==,es256,+presence
      '';
    };
  };

  # TODO: Test pam configuration before logging out with:
  # pamtester login <username> authenticate
  # pamtestr sudo <username> authenticate
}
