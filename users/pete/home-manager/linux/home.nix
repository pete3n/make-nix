# Home-manager configuration baseline for Linux systems
{
  inputs,
  lib,
  pkgs,
  makeNixLib,
  makeNixAttrs,
  homeModules,
  ...
}:
let
  # The system specialisation must support CUDA for the tag to apply
  hasCuda =
    makeNixLib.hasTag "cuda" makeNixAttrs.tags
    && makeNixLib.hasTag "wayland_dgpu" (makeNixAttrs.specialisations or [ ]);
  blender' = if hasCuda then pkgs.blender.override { cudaSupport = true; } else pkgs.blender;

  # Build the default Nixvim package for the system architecture
  nixvim' = [ inputs.nixvim.packages.${makeNixAttrs.system}.default ];

  makeUser = makeNixAttrs.user;
  makeHost = makeNixAttrs.host;
  makeTags = makeNixAttrs.tags;
  hasTag = makeNixLib.hasTag;
  optionalImport = tag: path: lib.optional (hasTag tag makeTags) path;
  optionalPkgs = tag: pkgList: lib.optionals (hasTag tag makeTags) pkgList;
in
{
  _module.args.hasCuda = hasCuda;

  imports =
    # Conditional imports based on configuration tags
    lib.optional (hasTag "aichat" makeTags || hasTag "local-ai" makeTags) ../cross-platform/aichat.nix
    ++ optionalImport "awesome" ./awesome-config.nix
    ++ optionalImport "gaming" ./gaming-config.nix
    ++ lib.optional (
      hasTag "git" makeTags || hasTag "git-ssh-user" makeTags
    ) ../cross-platform/git-config.nix
    ++ optionalImport "hyprland" ./hyprland-config.nix
    ++ optionalImport "mpd" ./mpd-config.nix
    ++ optionalImport "office" ./office-config.nix
    # Local home modules
    ++ builtins.attrValues homeModules
    ++ [
      ../cross-platform/alacritty-config.nix
      ../cross-platform/cli-programs.nix
      ../cross-platform/tmux-config.nix
      ./bash-config.nix
      ./firefox-config.nix
      ./rofi-config.nix
      ./theme-style.nix
      ./xdg-config.nix
    ]
    # Home modules from pete3n repo
    ++ [
      inputs.pete3n-mods.homeManagerModules.linux.default
    ];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  home = {
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "24.05";
    username = "${makeUser}";
    homeDirectory = "/home/${makeUser}";

    file = lib.optionalAttrs (hasTag "yubi-u2f" makeTags) {
      ".config/Yubico/u2f_keys" = {
        text = "${makeNixAttrs.user}:jPXIHluUKJNDbiCSQ5+DRfMrG+ZNqMyQXTHSyByi5XHSXHNhZC2CduqlqNOIutx2NIc8Qhn2omlCFpcOoDjukw==,FQlfOdBDXUlixODcx+4gDsFIyLaX21KWqkEmbVx3ny7iwJpL43O2BRMAcArBJWJ/tEsz2/lxI/gZk7Dn9093vA==,es256,+presence:4a218pdZXDWigFWVcGDubvTbdAN9cAlp9+r0CPezvDojRPeou4j1m6vv4ZqW70jzNhAd9HD4gV0ykhC4Uoxi0A==,ftm749QLZ7sgH9ITIyb+f3Wn4BXDjK32+qIMlkfkOnMZ8On6GWBteaITzdCZ6PRzbTCQPZ6TC+ylGLw/rn0Ewg==,es256,+presence";
      };
    };

    packages =
      (with pkgs; [

        # Nix tools
        nix-inspect # Awesome Nix flake explorer
        nix-melt # Flake lock explorer
        nix-search-tv # Awesome Nix package fuzzy finder
        nix-tree # Interactively browse Nix store dependencies

        # Misc
        bottles # Wine container manager
        borgbackup
        browsh # Terminal browser
        ddgr # Search duckduckgo from the terminal
        fdupes # Duplicate file finder
        kdePackages.okular # Okular PDF viewer
        kdePackages.dolphin # Dolphin file browser
        kdePackages.k3b # CD Burning GUI
        litemdview # Simple markdown viewer
        local.ipod-shuffle-4g
				local.vip-access # Provision Symantec VIP TOTP
        mosh # Mobile-shell SSH replacement
        nextcloud-client
        remmina
        rustdesk
        unstable.standardnotes
        unstable.yt-dlp # Youtube download Python version
        unzip
        vlc
        wf-recorder # Wayland screen recorder
        xdg-user-dirs
        zip

        ## CLI utilities
        age # Age encryption utilties
        asciinema # Terminal recorder
        bandwhich # Network utilization monitor
        cdrtools # CD writing tools
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
        #TODO: Alias for --relay-url=wss://mailbox.mw.leastauthority.com/v1
        magic-wormhole-rs # Easy remote file transfer - rust
        most # Better more/less pager
        mutt # Terminal email
        navi # Cheat-sheets
        nb # CLI note-taking
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
        vim
        xxgdb # gdb TUI

        ## Pen testing, network recon, binary analysis tools
        angryoxide
        aircrack-ng
        bettercap
        bingrep # Binary analysis search
        binwalk # Binary file analysis
        ffmpeg # Video encoding/transcoding
        file # Magic bit reader
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
        whois
      ]) ++ lib.optionals (makeNixAttrs.system == "x86_64-linux") (with pkgs; [
				unstable.cryptomator # Encrypted container GUI
        unstable.cryptomator-cli # Encrypted container CLI
			])
      ++ optionalPkgs "nixvim" nixvim'
      ++ optionalPkgs "media-creation" (
        # Multimedia creation and editing tools for 3d, audio, images, music, and video
        with pkgs;
        [
          audacity # Audio editor
          blender' # 3D editor
          bitwig-studio # DAW
          gimp-with-plugins # Image editing
          handbrake # DVD wripping
          inkscape-with-extensions # Vector graphics
          kdePackages.kdenlive # Video editing
        ]
      )
      ++ optionalPkgs "crypto" (
        # Crypto currency tools
        with pkgs;
        [
          unstable.bisq2
          unstable.monero-cli
          unstable.monero-gui
          unstable.sparrow
        ]
      )
      ++ optionalPkgs "messaging" (
        # Messaging apps
        with pkgs;
        [
          mod.no-gpu-signal-desktop
          unstable.element-desktop
          unstable.teams-for-linux
        ]
      )
      ++ optionalPkgs "sdr" [ pkgs.gnuradio ] # Software defined radio
      ++ optionalPkgs "yubi-age-user" (
				# Userland packages to support Yubikey system integration
        with pkgs;
        [
          age
          age-plugin-yubikey
          opensc
          pinentry-curses
          yubikey-manager
					yubioath-flutter
          yubikey-personalization
        ]
      )
      ++ optionalPkgs "yubi-u2f" (
				# Userland packages to support system level Yubikey u2f and pam integration
        with pkgs;
        [
          pam_u2f
          pamtester
        ]
      );
  };

  # systemd --user services
  services = {
    backup = {
      enable = (hasTag "p22" makeTags);
      local.destination = "/mnt/nfs/share/backups/${makeHost}-${makeUser}";
      patterns = [
        "R /home/${makeUser}"
        "- /home/${makeUser}/.cache"
        "- /home/${makeUser}/Downloads"
      ];
    };

    powerproud = {
      enable = true;
    };

    batmond = {
      enable = lib.mkDefault (makeNixLib.hasTag "laptop" makeTags);
    };

    khalNotify.enable = true;
  };

  accounts.calendar = {
    basePath = "~/.local/share/khal/calendars";
    accounts."default" = {
      primary = true;
      khal = {
        enable = true;
        color = "light blue";
        type = "calendar";
      };
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

    khal = {
      enable = true;
      locale = {
        local_timezone = "America/New_York";
        default_timezone = "America/New_York";
        timeformat = "%H:%M";
        dateformat = "%Y-%m-%d";
        datetimeformat = "%Y-%m-%d %H:%M";
        longdateformat = "%Y-%m-%d";
        longdatetimeformat = "%Y-%m-%d %H:%M:%S";
        firstweekday = 0;
      };
      settings = {
        default = {
          default_calendar = "default";
        };
      };
    };

    librewolf = {
      enable = true;
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "github" = {
          hostname = "github.com";
          user = "git";
          identityFile = [
            "/home/${makeUser}/.ssh/id_ed25519_sk_rk_github"
            "/home/${makeUser}/.ssh/pete3n"
          ];
          identitiesOnly = true;
        };
        "linode" = {
          hostname = "tech.p3n.dev";
          user = "ubuntu";
          identityFile = [
            "/home/${makeUser}/.ssh/id_ed25519_sk_rk_linode"
          ];
          identitiesOnly = true;
        };
      }
      // lib.optionalAttrs (hasTag "p22" makeTags) {
        "framework-dt" = {
          hostname = "framework-dt.p22";
          user = "pete";
          identityFile = "/home/${makeUser}/.ssh/id_ed25519_sk_rk_p22";
          identitiesOnly = true;
          extraOptions = {
            IdentityAgent = "none";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control-%r@%h:%p";
            ControlPersist = "10m";
          };
        };
        "backupsvr" = {
          hostname = "backupsvr.p22";
          user = "root";
          identityFile = "/home/${makeUser}/.ssh/id_ed25519_sk_rk_p22";
          identitiesOnly = true;
          extraOptions.IdentityAgent = "none";
        };
        "mediasvr" = {
          hostname = "media.p22";
          user = "root";
          identityFile = "/home/${makeUser}/.ssh/id_ed25519_sk_rk_p22";
          identitiesOnly = true;
          extraOptions.IdentityAgent = "none";
        };
      };
    };

    p22Sync = {
      enable = (hasTag "p22" makeTags);
      syncHosts = [
        {
          name = "framework-16";
          paths = [
            "Documents"
            "Downloads"
            "Music"
            "Nextcloud"
            "Pictures"
            "Projects"
            "Videos"
          ];
          excludePaths = [
            "Downloads/Work"
          ];
        }
        {
          name = "framework-dt";
          paths = [
            "Documents"
            "Downloads"
            "Music"
            "Nextcloud"
            "Pictures"
            "Projects"
            "Videos"
          ];
          excludePaths = [
            "Downloads/Work"
          ];
        }
        {
          name = "macbook";
          paths = [
            "Documents"
            "Downloads"
            "Music"
            "Nextcloud"
            "Pictures"
            "Projects"
            "Videos"
          ];
          excludePaths = [
            "Downloads/Work"
          ];
        }
        {
          name = "macmini";
          paths = [
            "Documents"
            "Downloads"
            "Music"
            "Nextcloud"
            "Pictures"
            "Projects"
            "Videos"
          ];
          excludePaths = [
            "Downloads/Work"
          ];
        }
      ];
    };

    # Import resident keys from Yubikey if any are missing from ~/.ssh
    yubi-ssh-import = {
      enable = (hasTag "yubi-ssh-import" makeTags);
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
