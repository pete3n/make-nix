{
  inputs,
  outputs,
  pkgs,
  makeNixAttrs,
  ...
}:
{
  imports = builtins.attrValues outputs.homeModules ++ [
    ../cross-platform/alacritty-config.nix
    ../cross-platform/git-config.nix
    ../cross-platform/cli-programs.nix
    ./firefox-config.nix
    ./tmux-config.nix
    ./zsh-config.nix
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
      [ inputs.nixvim.packages.${makeNixAttrs.system}.default ]
      ++ (with pkgs; [
        local.yubioath-darwin
        python312Packages.base58
      ]);
  };
}
