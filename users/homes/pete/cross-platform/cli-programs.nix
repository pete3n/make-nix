{ pkgs, make_opts, ... }:
let
  # Use Zsh integration for Darwin and Bash integration for Linux
  shellIntegration = {
    enableBashIntegration = make_opts.isLinux;
    enableZshIntegration = !make_opts.isLinux;
  };

  yaziTokyoNight = pkgs.fetchFromGitHub {
    owner = "BennyOe";
    repo = "tokyo-night.yazi";
    rev = "5f5636427f9bb16cc3f7c5e5693c60914c73f036";
    hash = "sha256-4aNPlO5aXP8c7vks6bTlLCuyUQZ4Hx3GWtGlRmbhdto=";
  };

  yaziOffice = pkgs.fetchFromGitHub {
    owner = "macydnah";
    repo = "office.yazi";
    rev = "41ebef8be9dded98b5179e8af65be71b30a1ac4d";
    hash = "sha256-QFto48D+Z8qHl7LHoDDprvr5mIJY8E7j37cUpRjKdNk=";
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

      flavors = {
        tokyo-night = yaziTokyoNight;
      };

      theme = {
        flavor = {
          use = "tokyo-night";
          dark = "tokyo-night";
        };
      };

      plugins = {
        office = yaziOffice;
      };

      settings = {
        plugin = {
          # Office.yazi configuration
          prepend_preloaders = [
            # Office Documents
            {
              mime = "application/openxmlformats-officedocument.*";
              run = "office";
            }
            {
              mime = "application/oasis.opendocument.*";
              run = "office";
            }
            {
              mime = "application/ms-*";
              run = "office";
            }
            {
              mime = "application/msword";
              run = "office";
            }
            {
              name = "*.docx";
              run = "office";
            }
          ];

          prepend_previewers = [
            # Office Documents
            {
              mime = "application/openxmlformats-officedocument.*";
              run = "office";
            }
            {
              mime = "application/oasis.opendocument.*";
              run = "office";
            }
            {
              mime = "application/ms-*";
              run = "office";
            }
            {
              mime = "application/msword";
              run = "office";
            }
            {
              name = "*.docx";
              run = "office";
            }
          ];
        };

      };

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
    chafa # ASCII fallback
    ffmpegthumbnailer
    imagemagick
    # Image decoding
    odt2txt # Open doc preview
    pandoc # Document conversion
    poppler-utils # PDF Preview
    ueberzugpp # image overlay
    w3m # Text-based web browser
  ];
}
