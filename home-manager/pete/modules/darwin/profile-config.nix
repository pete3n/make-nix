{config, ...}: {
  programs.git = {
    enable = true;
    userName = "pete3n";
    userEmail = "pete3n@protonmail.com";
    extraConfig = {
      core.editor = "nvim";
      init = {
        defaultBranch = "main"; # Github default
        templateDir = "${config.home.homeDirectory}/.git-templates";
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

  programs.bash = {
    initExtra = let
      ssh-private-key = "pete3n";
    in
      /*
      bash
      */
      ''
              if command -v keychain > /dev/null 2>&1; then
              	eval $(keychain --eval --nogui ${ssh-private-key} --quiet);
              fi

              set -o vi

              alias screenshot=grim
              alias ls=lsd
        alias lsc='lsd --classic'
      '';

    profileExtra =
      /*
      bash
      */
      ''
        export EDITOR=nvim
      '';
  };
}
