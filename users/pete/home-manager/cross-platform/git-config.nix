{
  lib,
  config,
  makeNixAttrs,
  makeNixLib,
  ...
}:
let
  makeUser = makeNixAttrs.user;
  gitKeys = lib.optionals (
    makeNixLib.hasTag "git-ssh-user" makeNixAttrs.tags && !makeNixAttrs.isHomeAlone
  ) [ "pete3n" ];

  # Use Zsh integration for Darwin and Bash integration for Linux
  shellIntegration = {
    enableBashIntegration = makeNixLib.isLinux makeNixAttrs.system;
    enableZshIntegration = makeNixLib.isDarwin makeNixAttrs.system;
  };
in
{
  programs = {
    ssh = {
      settings = {
        "github github.com" = {
          HostName = "github.com";
          User = "git";
          IdentityFile = [
            "/home/${makeUser}/.ssh/id_ed25519_sk_rk_github"
            "/home/${makeUser}/.ssh/pete3n"
          ];
          IdentitiesOnly = true;
        };
      };
    };

    git = {
      enable = true;
      lfs.enable = true;
      settings = {
        core.editor = "nvim";
        init = {
          defaultBranch = "main";
          templateDir = "${config.home.homeDirectory}/.git-templates";
        };
        user = {
          name = "pete3n";
          email = "pete3n@protonmail.com";
        };
      };
    };

    lazygit = {
      enable = true;
    };

    keychain = {
      enable = true;
      keys = gitKeys;
    }
    // shellIntegration;
  };

  home.file.".git-templates/gitlint".text = ''
    [general]
    ignore=title-trailing-punctuation, T3
    contrib=contrib-title-conventional-commits,CC1
    #extra-path=./gitlint_rules/my_rules.py

    ### Configuring rules ###
    [title-max-length]
    line-length=80

    [title-min-length]
    min-length=5
  '';
}
