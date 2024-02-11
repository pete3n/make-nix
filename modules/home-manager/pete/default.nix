{
  alacritty-config = import ./alacritty-config.nix;
  awesome-config = import ./awesome-config.nix;
  user-config = import ./pete-config.nix;
  crypto = import ./crypto.nix;
  firefox-config = import ./firefox.nix;
  hyprland-config = import ./hyprland-config.nix;
  media-tools = import ./media-tools.nix;
  messengers = import ./messengers.nix;
  office-cloud = import ./office-cloud.nix;
  pen-tools = import ./pen-tools.nix;
  neovim-env = import ./neovim-env.nix;
  theme-style = import ./theme-style.nix;
  tmux-config = import ./tmux-config.nix;
}
