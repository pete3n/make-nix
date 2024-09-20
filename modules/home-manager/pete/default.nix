{
  alacritty-config = import ./alacritty-config.nix;
  awesome-config = import ./awesome-config.nix;
  crypto = import ./crypto.nix;
  firefox-config = import ./firefox.nix;
  games = import ./games.nix;
  hyprland-config = import ./hyprland-config.nix;
  media-tools = import ./media-tools.nix;
  messengers = import ./messengers.nix;
  misc-tools = import ./misc-tools.nix;
  neovim-env = import ./neovim-env.nix;
  office-cloud = import ./office-cloud.nix;
  pen-tools = import ./pen-tools.nix;
  theme-style = import ./theme-style.nix;
  tmux-config = import ./tmux-config.nix;
  user-config = import ./pete-config.nix;
  quirks = import ./quirks.nix;
}
