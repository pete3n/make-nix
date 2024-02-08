# This file contains unique username based configuration options
{pkgs, ...}: {
  home = {
    username = "pete";
    homeDirectory = "/home/pete";
  };

  programs.git = {
    enable = true;
    userName = "pete3n";
    userEmail = "pete3n@protonmail.com";
    extraConfig = {
      core.editor = "nvim";
      #commit.gpgsign = true;
      #gpg.format = "ssh";
      #gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signer";
      #user.signingkey = "~/.ssh/pete3n.pub";
    };
  };
}
