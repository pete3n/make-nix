{
  pkgs,
  makeNixLib,
  makeNixAttrs,
  ...
}:
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

	home.packages = [
		pkgs.devenv
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
    }
    // shellIntegration;
    # Starship cross-shell prompt config
    starship = {
      enable = true;
      settings = {
        directory = {
          truncation_length = 0; # Disable truncation to show the full path
        };
      };
    }
    // shellIntegration;
    # Recursive grep
    ripgrep = {
      enable = true;
    };
    # Zathura PDF viewer with VIM motions
    zathura = {

  # Temporary fixes for upstream nixpkgs build failures
    # HACK: workaround for nixpkgs#514566 / PR#515614
    # appstream meson build leaks "none required" into darwin linker flags
    # when libsystemd dep resolves as not-found on darwin.
    # Remove once PR#515614 reaches release-26.05
      enable = pkgs.stdenv.hostPlatform.isLinux;
    };
    # Zoxide better cd replacement with memory
    zoxide = {
      enable = true;
    }
    // shellIntegration;
  };
}
