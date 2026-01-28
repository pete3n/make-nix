# Home-manager configuration
{
  inputs,
  lib,
  pkgs,
  makeNixAttrs,
  homeModules,
  ...
}:

# "Tags" allow customizable user-based configuration at evaluation time similar
# to specialisations for the system.
# Simply add a tag string to the list of linuxTags, and then define and import
# list for it in tagMap.
# Even though we are building for users, we can still customize some
# system based configuration and demonstrate the power of Nix to provide
# a declarative outcome: get a working Hyprland WM, regardless of
# if we are using NixOS or a different Linux distribution.
let
  linuxTags = [ "hyprland" ];

  availableTags = builtins.filter (tag: builtins.elem tag linuxTags) makeNixAttrs.tags;

  tagImportMap = {
    hyprland = [
      ./hyprland-config.nix
    ];
  };

  tagImports = lib.flatten (builtins.map (tag: tagImportMap.${tag}) availableTags);

  blenderCuda = pkgs.blender.override {
    # Build Blender with CUDA support
    cudaSupport = true;
  };

in
{
  imports =
    builtins.attrValues homeModules
    ++ [
      ../cross-platform/alacritty-config.nix
      ../cross-platform/git-config.nix
      ../cross-platform/cli-programs.nix
      ./awesome-config.nix
      ./bash-config.nix
      ./firefox-config.nix
      ./media-tools.nix
      ./theme-style.nix
      ./tmux-config.nix
      ./yubikey-u2f.nix
    ]
    ++ tagImports;

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  xdg = {
    enable = true;
    portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      xdgOpenUsePortal = true;
      config = {
        common = {
          default = [ "gtk" ];
        };
      };
    };

    userDirs = {
      enable = true;
      documents = "/home/${makeNixAttrs.user}/Documents";
      download = "/home/${makeNixAttrs.user}/Downloads";
      music = "/home/${makeNixAttrs.user}/Music";
      pictures = "/home/${makeNixAttrs.user}/Pictures";
      publicShare = "/home/${makeNixAttrs.user}/Public";
      templates = "/home/${makeNixAttrs.user}/Templates";
      videos = "/home/${makeNixAttrs.user}/Videos";

      extraConfig = {
        XDG_PROJECT_DIR = "/home/${makeNixAttrs.user}/Projects";
      };
    };
  };

  home = {
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "24.05";
    username = "${makeNixAttrs.user}";
    homeDirectory = "/home/${makeNixAttrs.user}";

    packages =
      # Build the default Nixvim package for the system architecture
      [ inputs.nixvim.packages.${makeNixAttrs.system}.default ]
      ++ (with pkgs; [

        # Misc
        bottles # Wine container manager
        borgbackup
        browsh # Terminal browser
        unstable.cryptomator # Encrypted container GUI
        fdupes # Duplicate file finder
        heroic # Heroic game launcher
        kdePackages.okular # Okular PDF viewer
        libreoffice
        litemdview # Simple markdown viewer
        mod._86Box
        mosh # Mobile-shell SSH replacement
        nextcloud-client
        onlyoffice-desktopeditors
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
				age # Age encryption utilties
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
				lsof # List open files
        lynx # Text-mode browser
        magic-wormhole # Easy remote file transfer - python
        magic-wormhole-rs # Easy remote file transfer - rust
        most # Better more/less pager
        mutt # Terminal email
        navi # Cheat-sheets
        nb # CLI note-taking
				nix-search-tv # Awesome Nix package fuzzy finder
				nix-inspect # Awesome Nix flake explorer
        nix-tree # Interactively browse Nix store dependencies
        procs # Better process viewer
        python311Packages.base58
        repgrep # ripgrep replace
        ripgrep-all # rg with PDF, office doc, compress file support
        rsync
        sd # Better sed
				sops # Secrets management
        speedtest-cli # Internet speed test CLI
        sshs # SSH config manager TUI
        tldr # Better man pages
        unstable.cryptomator-cli # Encrypted container CLI
        vim
        xxgdb # gdb TUI

        ### Media tools
        drawio # Open Visio replacement
        gimp-with-plugins # Image editing
        handbrake # DVD wripping
        inkscape-with-extensions # Vector graphics
        rhythmbox # Music player
        kdePackages.kdenlive # Video editing
        vlc # Media player
        unstable.yt-dlp # Youtube download Python version
        wf-recorder # Wayland screen recorder
        ytfzf # Youtbue fuzzy finder and console viewer

        ## Pen testing, network recon, binary analysis tools
        angryoxide
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
      ])
      ++ lib.optionals pkgs.stdenv.isLinux [
        blenderCuda
      ];
  };

  # systemd --user services
  services = {
    backup = {
      enable = true;
      # TODO: Configure dynamically
      local.destination = "/mnt/nfs/share/backups/fw16-pete";
      patterns = [
        "R /home/${makeNixAttrs.user}"
        "- /home/${makeNixAttrs.user}/.cache"
        "- /home/${makeNixAttrs.user}/Downloads"
      ];
    };

    battery-minder = {
      enable = true;
    };

    power-profile-switcher = {
      enable = true;
    };
  };

  # Modules with additional program configuration
  programs = {
    home-manager.enable = true;
    nix-search-tv = {
      enable = true;
      enableTelevisionIntegration = true;
    };

    firefox = {
      enable = true;
    };

    librewolf = {
      enable = true;
    };

		ssh = {
			enable = true;
			enableDefaultConfig = false;
			matchBlocks = {
				"framework-dt" = {
					hostname = "framework-dt.p22";
					user = "pete";
					identityFile = "/home/${makeNixAttrs.user}/.ssh/id_ed25519_sk_rk_p22";
					identitiesOnly = true;
				};
				"backupsvr" = {
					hostname = "backupsvr.p22";
					user = "root";
					identityFile = "/home/${makeNixAttrs.user}/.ssh/id_ed25519_sk_rk_p22";
					identitiesOnly = true;
				};
				"mediasvr" = {
					hostname = "media.p22";
					user = "root";
					identityFile = "/home/${makeNixAttrs.user}/.ssh/id_ed25519_sk_rk_p22";
					identitiesOnly = true;
				};
				"github" = {
					hostname = "github.com";
					user = "git";
					identityFile = "/home/${makeNixAttrs.user}/.ssh/id_ed25519_sk_rk_github";
					identitiesOnly = true;
				};
			};
		};

		# Import resident keys from Yubikey if any are missing from ~/.ssh
		import-yubikey-ssh = {
			enable = true;
			userKeys = [
				"id_ed25519_sk_rk_aws"
				"id_ed25519_sk_rk_github"
				"id_ed25519_sk_rk_linode"
				"id_ed25519_sk_rk_p22"
			];
		};

    clip58.enable = true;
    quick-notes.enable = true;

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
