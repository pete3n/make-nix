{ pkgs, ... }:
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
  };
  fonts = {
    # X11 support
    fontconfig = {
      enable = true;
      defaultFonts.monospace = [ "JetBrains Mono" ];
      defaultFonts.emoji = [ "Noto Color Emoji" ];
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
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };
}
