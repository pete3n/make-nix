{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Workaround for OnlyOffice font issue:
  # https://github.com/NixOS/nixpkgs/issues/373521
  hmFonts = "${config.home.profileDirectory}/share/fonts";
  ooFonts = "${config.xdg.dataHome}/fonts/onlyoffice"; # ~/.local/share/fonts/onlyoffice
in
{
  home = {
    packages = with pkgs; [
      dconf # Needed by gtk
      corefonts
      gnome-tweaks
      themechanger
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-monochrome-emoji
    ];

    pointerCursor = {
      gtk = {
        enable = true;
      };
      # x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 16;
    };
    # Populate ~/.local/share/fonts with ttf files (not symlinks)
    activation.onlyofficeUserFonts =
      lib.hm.dag.entryAfter [ "writeBoundary" ] # sh
        ''
          set -eu

          rm -rf "${ooFonts}"
          mkdir -p "${ooFonts}"

          # Copy actual files (dereference symlinks with -L)
          if [ -d "${hmFonts}" ]; then
          	${pkgs.rsync}/bin/rsync -aL \
          	--include='*/' --include='*.ttf' --include='*.otf' --exclude='*' \
          	"${hmFonts}/" "${ooFonts}/"
          fi
					chmod -R 744 "${ooFonts}"

          ${pkgs.findutils}/bin/find "${ooFonts}" -type f \( -name '*.ttf' -o -name '*.otf' \) -exec chmod 0644 {} \;
          ${pkgs.fontconfig}/bin/fc-cache -f "${ooFonts}" >/dev/null 2>&1 || true
        '';
  };

  fonts = {
    # X11 support
    fontconfig = {
      enable = true;
      defaultFonts.monospace = [ "JetBrains Mono" ];
      defaultFonts.emoji = [ "Noto Color Emoji" ];
    };
  };

  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Tokyonight-Dark";
        icon-theme = "Yaru-magenta";
        cursor-theme = "Bibata-Modern-Classic";
        font-name = "Sans Regular 11";
      };
    };
  };

  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;

    font = {
      name = "Sans Regular";
      size = 11;
    };

    iconTheme = {
      name = "Yaru-magenta";
      package = pkgs.yaru-theme;
    };

    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyonight-gtk-theme;
    };

    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
    };

  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };
}
