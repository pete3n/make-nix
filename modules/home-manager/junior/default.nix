{
  alacritty-config = import ./alacritty-config.nix;
  awesome-config = import ./awesome-config.nix;
  user-config = import ./pete-config.nix;
  hyprland-config = import ./hyprland-config.nix;
  media-tools = import ./media-tools.nix;
  misc-tools = import ./misc-tools.nix;
  pen-tools = import ./pen-tools.nix;
  neovim-env = import ./neovim-env.nix;
  theme-style = import ./theme-style.nix;
  tmux-config = import ./tmux-config.nix;
}
