{ config, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      core.editor = "nvim";
      init = {
        defaultBranch = "main"; # Github default
        templateDir = "${config.home.homeDirectory}/.git-templates";
      };
      user = {
        name = "pete3n";
        email = "pete3n@protonmail.com";
      };
    };
  };

  home.file.".git-templates/gitlint".text = ''
    [general]
    # Ignore rules, reference them by id or name (comma-separated)
    ignore=title-trailing-punctuation, T3

    # Enable specific community contributed rules
    contrib=contrib-title-conventional-commits,CC1

    # Set the extra-path where gitlint will search for user defined rules
    #extra-path=./gitlint_rules/my_rules.py

    ### Configuring rules ###
    [title-max-length]
    line-length=80

    [title-min-length]
    min-length=5
  '';
}
