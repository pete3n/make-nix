{
  inputs,
  lib,
  pkgs,
  makeNixAttrs,
  makeNixLib,
  homeModules,
  ...
}:
let
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
  imports =
    lib.optional (
      hasTag "git" makeTags || hasTag "git-ssh-user" makeTags
    ) ../cross-platform/git-config.nix
    ++ builtins.attrValues homeModules
    ++ [
      ../cross-platform/alacritty-config.nix
      ../cross-platform/cli-programs.nix
      ./firefox-config.nix
      ./tmux-config.nix
      ./zsh-config.nix
    ];

  nixpkgs = {
    overlays = [
      inputs.nixpkgs-firefox-darwin.overlay
    ];
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-communityUsers-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  # launchd services
  services = {
    backup = {
      enable = (hasTag "p22" makeTags);
      local.destination = "/Volumes/nfs/share/backups/${makeHost}-${makeUser}";
      patterns = [
        "R /Users/${makeUser}"
        "- /Users/${makeUser}/.cache"
        "- /Users/${makeUser}/Downloads"
      ];
    };
  };

  programs = {
    home-manager.enable = true;

    clip58.enable = true;

    nix-search-tv = {
      enable = true;
      enableTelevisionIntegration = true;
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "github" = {
          hostname = "github.com";
          user = "git";
          identityFile = [
            "/Users/${makeUser}/.ssh/id_ed25519_sk_rk_github"
            "/Users/${makeUser}/.ssh/pete3n"
          ];
          identitiesOnly = true;
        };
      }
      // lib.optionalAttrs (hasTag "p22" makeTags) {
        "framework-dt" = {
          hostname = "framework-dt.p22";
          user = "pete";
          identityFile = "/Users/${makeUser}/.ssh/id_ed25519_sk_rk_p22";
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
          identityFile = "/Users/${makeUser}/.ssh/id_ed25519_sk_rk_p22";
          identitiesOnly = true;
          extraOptions.IdentityAgent = "none";
        };
        "mediasvr" = {
          hostname = "media.p22";
          user = "root";
          identityFile = "/Users/${makeUser}/.ssh/id_ed25519_sk_rk_p22";
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
  };

  fonts.fontconfig.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "24.05";
    username = "${makeUser}";
    homeDirectory = "/Users/${makeUser}";

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
        borgbackup
        browsh # Terminal browser
        ddgr # Search duckduckgo from the terminal
        fdupes # Duplicate file finder
        local.ipod-shuffle-4g
        unstable.yt-dlp # Youtube download Python version
        unzip
        vlc
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
        #TODO: Alias for --relay-url=wss://mailbox.mw.leastauthority.com/v1
        magic-wormhole
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
        speedtest-cli # Internet speed test CLI
        sshs # SSH config manager TUI
        tldr # Better man pages
        unstable.cryptomator-cli # Encrypted container CLI
        vim
        xxgdb # gdb TUI
      ])
      ++ optionalPkgs "messaging" (
        # Messaging apps
        with pkgs;
        [
          mod.no-gpu-signal-desktop
          unstable.element-desktop
        ]
      )
      ++ optionalPkgs "nixvim" nixvim'
      ++ optionalPkgs "yubi-age-user" (
        with pkgs;
        [
          age
          age-plugin-yubikey
          opensc
          yubikey-manager
					local.yubioath-darwin
          yubikey-personalization
          pinentry_mac
        ]
      );
  };
}
