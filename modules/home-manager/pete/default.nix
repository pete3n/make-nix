{
  config = import ./pete-config.nix;
  alacritty-config = import ./alacritty-config.nix;
  hyprland-config = import ./hyprland-config.nix;
  media-tools = import ./media-tools.nix;
  neovim-env = import ./neovim-env.nix;
  theme-style = import ./theme-style.nix;
  tmux-config = import ./tmux-config.nix;
}
