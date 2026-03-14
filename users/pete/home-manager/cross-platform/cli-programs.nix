{ pkgs, makeNixLib, makeNixAttrs, ... }:
let
  # Use Zsh integration for Darwin and Bash integration for Linux
  shellIntegration = {
    enableBashIntegration = makeNixLib.isLinux makeNixAttrs.system;
    enableZshIntegration = makeNixLib.isDarwin makeNixAttrs.system;
  };
in
{
	imports = [
		(import ./yazi-config.nix { inherit pkgs shellIntegration; })
	];

  programs = {
    # Local wallpaper-scripts module for changing wallpapers
    wallpaper-scripts = {
      enable = true;
      os = if makeNixLib.isLinux makeNixAttrs.system then "linux" else "darwin";
    };
    # Better cat
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
      };
      extraPackages = with pkgs.bat-extras; [
        batdiff
        batman
        batgrep
        batwatch
      ];
    };
    # Better top resource monitor
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
        theme_background = false;
        color_theme = "nord";
      };
    };
    # LSDeluxe improved ls command
    lsd = {
      enable = true;
    };
    # Fastfetch neofetch replacement
    fastfetch = {
      enable = true;
    };
    # Fuzzy finder
    fzf = {
      enable = true;
    } // shellIntegration;
    keychain = {
      enable = true;
      keys = [ "pete3n" ];
    } // shellIntegration;
    # Starship cross-shell prompt config
    starship = {
      enable = true;
      settings = {
        directory = {
          truncation_length = 0; # Disable truncation to show the full path
        };
      };
    } // shellIntegration;
    # Recursive grep
    ripgrep = {
      enable = true;
    };
    # Zathura PDF viewer with VIM motions
    zathura = {
      enable = true;
    };
    # Zoxide better cd replacement with memory
    zoxide = {
      enable = true;
    } // shellIntegration;
  };
}
