{
  config,
  makeNixAttrs,
  ...
}:
{
  programs.yubi-age-decrypt = {
    enable = makeNixAttrs.isHomeAlone;
    secrets = [
      {
        outputFile = "${config.home.homeDirectory}/.ssh/pete3n";
        ageFile = "${../../secrets/pete3n.age}";
        identityFile = "${../../secrets/age-plugin-yubikeys}";
      }
    ];
  };

  programs.git = {
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
