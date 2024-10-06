{
  inputs,
  outputs,
  pkgs,
  build_target,
  ...
}:
{
  imports = builtins.attrValues outputs.homeManagerModules ++ [
    ./home-imports/cross-platform/alacritty-config.nix
    ./home-imports/cross-platform/git-config.nix
    ./home-imports/linux/bash-config.nix
    ./home-imports/linux/firefox-config.nix
    ./home-imports/linux/hyprland-config.nix
    ./home-imports/linux/rofi-theme.nix
    ./home-imports/linux/theme-style.nix
    ./home-imports/linux/tmux-config.nix
    ./home-imports/linux/waybar-config.nix
  ];

  nixpkgs = {
    overlays = [
      outputs.overlays.unstable-packages
      outputs.overlays.local-packages
      outputs.overlays.mod-packages
    ];
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  fonts.fontconfig.enable = true;

  home = {
    username = "pete";
    homeDirectory = "/home/pete";
    packages =
      [ inputs.nixvim.packages.${build_target.system}.default ]
      ++ (with pkgs; [

        # Misc
        bottles # Wine container manager
        browsh # Terminal browser
        cryptomator
        fdupes # Duplicate file finder
        heroic # Heroic game launcher
        litemdview # Simple markdown viewer
        mod._86Box
        mosh # Mobile-shell SSH replacement
        nextcloud-client
        onlyoffice-bin
        pika-backup
        protonmail-bridge
        remmina
        standardnotes
        thunderbird
        unstable.bisq-desktop
        unstable.monero-cli
        unstable.monero-gui
        unzip
        xdg-user-dirs
        xfce.thunar # Lightweight graphical file browser
        zip

        ## Messaging apps
        mod.no-gpu-signal-desktop
        unstable.element-desktop
        unstable.skypeforlinux
        unstable.teams-for-linux

        ## CLI utilities
        asciinema # Terminal recorder
        bandwhich # Network utilization monitor
        cdrkit # CD writing tools
        ctop # Container resource monitor
        diff-so-fancy # Better looking diffs
        duf # Better du/df
        entr # File watch event trigger
        exiftool # Read/write photo metadata
        fd # Find replacement
        gdu # Graphical disk usage TUI
        gron # Grep JSON
        hyperfine # CLI benchmark tool
        jc # JSON converter
        jq # JSON processor
        lazydocker # Docker TUI
        lynx # Text-mode browser
        magic-wormhole # Easy remote file transfer - python
        magic-wormhole-rs # Easy remote file transfer - rust
        most # Better more/less pager
        mutt # Terminal email
        navi # Cheat-sheets
        nb # CLI note-taking
        nix-tree # Interactively browse Nix store dependencies
        procs # Better process viewer
        python311Packages.base58
        ripgrep-all # rg with PDF, office doc, compress file support
        rsync
        sd # Better sed
        speedtest-cli # Internet speed test CLI
        sshs # SSH config manager TUI
        tldr # Better man pages
        vim
        xxgdb # gdb TUI

        ### Media tools
        drawio # Open Visio replacement
        gimp # Image editing
        handbrake # DVD wripping
        rhythmbox # Music player
        shotcut # Video editing
        vlc # Media player
        unstable.yt-dlp # Youtube download Python version
        ytfzf # Youtbue fuzzy finder and console viewer

        ## Pen testing, network recon, binary analysis tools
        local.angryoxide
        aircrack-ng
        bettercap
        bingrep # Binary analysis search
        binwalk # Binary file analysis
        chisel
        ffmpeg # Video encoding/transcoding
        file # Magic bit reader
        gnuradio
        gpsd
        hashcat
        hcxdumptool
        hcxtools
        masscan
        ngrep # Network packet analyzer
        nmap # Network mapping
        proxychains
        reaverwps-t6x
        rustscan
        socat
        termshark
        wireshark
      ]);
  };

  # Modules with additional program configuration
  programs = {
    home-manager.enable = true;

    # Local wallpaper-scripts module for changing wallpapers
    wallpaper-scripts = {
      enable = true;
      os = "linux";
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
      enableAliases = true;
    };
    # Fastfetch neofetch replacement
    fastfetch = {
      enable = true;
    };
    # Fuzzy finder
    fzf = {
      enable = true;
      enableBashIntegration = true;
    };
    keychain = {
      enable = true;
      enableBashIntegration = true;
      agents = [
        "ssh"
        "gpg"
      ];
      keys = [ "pete3n" ];
    };
    # Starship cross-shell prompt config
    starship = {
      enable = true;
      enableBashIntegration = true;
    };
    # Recursive grep
    ripgrep = {
      enable = true;
    };
    # Yazi cli file manager
    yazi = {
      enable = true;
      enableBashIntegration = true;
    };
    # Zathura PDF viewer with VIM motions
    zathura = {
      enable = true;
    };
    # Zoxide better cd replacement with memory
    zoxide = {
      enable = true;
      enableBashIntegration = true;
    };
    firefox = {
      enable = true;
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  services = {
    dunst = {
      enable = true; # Enable dunst notification daemon
      settings = {
        global = {
          corner_radius = 10;
          background = "#1f2335";
        };
      };
    };
    ssh-agent.enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
