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
    ./home-imports/cross-platform/cli-programs.nix
    ./home-imports/linux/awesome-config.nix
    ./home-imports/linux/bash-config.nix
    ./home-imports/linux/firefox-config.nix
    ./home-imports/linux/hyprland-config.nix
    ./home-imports/linux/media-tools.nix
    ./home-imports/linux/theme-style.nix
    ./home-imports/linux/tmux-config.nix
    ./home-imports/linux/yubikey-u2f.nix
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

  home = {
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "24.05";
    username = "pete";
    homeDirectory = "/home/pete";
    packages =
      [ inputs.nixvim.packages.${build_target.system}.default ]
      ++ (with pkgs; [

        # Misc
        bottles # Wine container manager
        browsh # Terminal browser
        unstable.cryptomator
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
        unstable.standardnotes
        thunderbird
        unstable.monero-cli
        unstable.bisq2
        unstable.monero-gui
        unzip
        xdg-user-dirs
        xfce.thunar # Lightweight graphical file browser
        zip

        ## Messaging apps
        mod.no-gpu-signal-desktop
        rustdesk-flutter
        unstable.element-desktop
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
        repgrep # ripgrep replace
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
        inkscape-with-extensions # Vector graphics
        rhythmbox # Music player
        kdenlive # Video editing
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
    #++ (if display_server == "x11" then [ pkgs.hello ] else [ ]);
  };

  # Modules with additional program configuration
  programs = {
    home-manager.enable = true;

    firefox = {
      enable = true;
    };

    lazydocker = {
      enable = true;
      customCommands = {
        containers = [
          {
            name = "Interactive bash shell";
            attach = true;
            command = "docker exec -it {{ .Container.ID }} /bin/bash";
            serviceNames = [ ];
            stream = true;
            description = "Open an interactive bash shell in the running container.";
          }
        ];
        images = [
          {
            name = "Run shell in new container from image";
            attach = true;
            command = "docker run -it --rm {{ .Image.ID }} /bin/sh";
            serviceNames = [ ];
            stream = true;
            description = "Run shell in new container from an image";
          }
        ];
      };
    };

    # TODO: Config
    lazygit = {
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
}
