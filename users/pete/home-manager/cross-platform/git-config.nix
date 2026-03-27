{
  lib,
  config,
  makeNixAttrs,
  makeNixLib,
  ...
}:
let
  gitKeys = lib.optionals (makeNixLib.hasTag "git-user" makeNixAttrs.tags) (
    [ "pete3n" ] ++ lib.optionals (!makeNixAttrs.isHomeAlone) [ ]
  );

  # Use Zsh integration for Darwin and Bash integration for Linux
  shellIntegration = {
    enableBashIntegration = makeNixLib.isLinux makeNixAttrs.system;
    enableZshIntegration = makeNixLib.isDarwin makeNixAttrs.system;
  };
in
{
  programs = {
    git = {
      enable = true;
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
