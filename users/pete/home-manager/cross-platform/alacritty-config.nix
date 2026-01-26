{ config, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      general = {
        working_directory = config.home.homeDirectory;
      };
      window = {
        decorations = "None";
        opacity = 0.7;
        padding = {
          x = 5;
          y = 5;
        };
      };
      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        size = 14;
      };
      colors = {
        primary = {
          background = "#090300";
          foreground = "#a5a2a2";
        };
        cursor = {
          text = "#090300";
          cursor = "#a5a2a2";
        };
        normal = {
          black = "#090300";
          red = "#db2d20";
          green = "#01a252";
          yellow = "#fded02";
          blue = "#01a0e4";
          magenta = "#a16a94";
          cyan = "#b5e4f4";
          white = "#a5a2a2";
        };
        bright = {
          black = "#5c5855";
          red = "#db2d20";
          green = "#01a252";
          yellow = "#fded02";
          blue = "#01a0e4";
          magenta = "#a16a94";
          cyan = "#b5e4f4";
          white = "#f7f7f7";
        };
      };
    };
  };
}
