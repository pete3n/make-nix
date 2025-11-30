{ pkgs, make_opts, ... }:
let
  # Use Zsh integration for Darwin and Bash integration for Linux
  shellIntegration = {
    enableBashIntegration = make_opts.isLinux;
    enableZshIntegration = !make_opts.isLinux;
  };
in
{
  programs = {
    # Local wallpaper-scripts module for changing wallpapers
    wallpaper-scripts = {
      enable = true;
      os = if make_opts.isLinux then "linux" else "darwin";
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
      agents = [
        "ssh"
        "gpg"
      ];
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
    # Yazi cli file manager
    yazi = {
      enable = true;
    } // shellIntegration;

    # Zathura PDF viewer with VIM motions
    zathura = {
      enable = true;
    };
    # Zoxide better cd replacement with memory
    zoxide = {
      enable = true;
    } // shellIntegration;
  };

	# Extra packages for media in CLI
  home.packages = with pkgs; [
    ueberzugpp # image overlay
    chafa # ASCII fallback
    imagemagick # Image decoding
    ffmpegthumbnailer
    poppler-utils # PDF Preview
  ];
}
