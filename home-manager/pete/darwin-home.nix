{
  inputs,
  outputs,
  pkgs,
  make_opts,
  ...
}:
{
  imports = builtins.attrValues outputs.homeModules ++ [
    ./home-imports/cross-platform/alacritty-config.nix
    ./home-imports/cross-platform/git-config.nix
    ./home-imports/cross-platform/cli-programs.nix
    ./home-imports/darwin/firefox-config.nix
    ./home-imports/darwin/tmux-config.nix
    ./home-imports/darwin/zsh-config.nix
  ];

  nixpkgs = {
    overlays = [
      inputs.nixpkgs-firefox-darwin.overlay
      outputs.overlays.local-packages
    ];
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  programs = {
    home-manager.enable = true;
  };
  fonts.fontconfig.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "24.05";
    username = "pete";
    homeDirectory = "/Users/pete";

    packages =
      [ inputs.nixvim.packages.${make_opts.system}.default ]
      ++ (with pkgs; [
        local.yubioath-darwin
        python312Packages.base58
      ]);
  };
}
