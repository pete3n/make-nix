{ pkgs, shellIntegration, ... }:
let
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

  # Yazi cli file manager
  programs.yazi = {
    enable = true;

    keymap = {
      mgr = {
        prepend_keymap = [
          {
            # g > i
            on = [
              "g"
              "i"
            ];
            run = "plugin lazygit";
            desc = "run lazygit";
          }

          {
            # g > p
            on = [
              "g"
              "p"
            ];
            run = "cd ~/Projects";
            desc = "go ~/Projects";
          }

        ];
      };
    };

    plugins = {
      "office" = yaziOffice;
			"ouch" = pkgs.yaziPlugins.ouch;
			"lazygit" = pkgs.yaziPlugins.lazygit;
    };

    settings = {
      mgr = {
        linemode = "size";
      };

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

      flavors = {
        tokyo-night = yaziTokyoNight;
      };

      theme = {
        flavor = {
          use = "tokyo-night";
          dark = "tokyo-night";
        };
      };
    };

  } // shellIntegration;
}
