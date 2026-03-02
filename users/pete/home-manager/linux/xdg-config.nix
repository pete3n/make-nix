{ pkgs, makeNixAttrs, ... }:
{
  home.packages = with pkgs; [
    desktop-file-utils
    kdePackages.kservice # provides kbuildsycoca6
    kdePackages.kio-extras
    kdePackages.kmenuedit
  ];
  xdg = {
    enable = true;
    portal = {
      enable = true;
      extraPortals = [
        pkgs.kdePackages.xdg-desktop-portal-kde
        pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-gtk
      ];
      xdgOpenUsePortal = true;
      config = {
        common = {
          default = [
            "hyprland"
            "kde"
          ];
        };
        # Route file picking to kde/gtk depending on app toolkit
        "org.freedesktop.impl.portal.FileChooser" = {
          default = [ "kde" ];
        };
        "org.freedesktop.impl.portal.Screenshot" = {
          default = [ "hyprland" ];
        };
        "org.freedesktop.impl.portal.ScreenCast" = {
          default = [ "hyprland" ];
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

    mimeApps = {
      enable = true;
      associations.added = {
        "application/pdf" = [ "org.kde.okular.desktop" ];
        "video/mp4" = [ "vlc.desktop" ];
        "video/x-matroska" = [ "vlc.desktop" ];
        "video/x-msvideo" = [ "vlc.desktop" ];
        "video/quicktime" = [ "vlc.desktop" ];
        "video/webm" = [ "vlc.desktop" ];
        "video/mpeg" = [ "vlc.desktop" ];
      };
      defaultApplications = {
        "application/pdf" = [ "org.kde.okular.desktop" ];
        "video/mp4" = [ "vlc.desktop" ];
        "video/x-matroska" = [ "vlc.desktop" ];
        "video/x-msvideo" = [ "vlc.desktop" ];
        "video/quicktime" = [ "vlc.desktop" ];
        "video/webm" = [ "vlc.desktop" ];
        "video/mpeg" = [ "vlc.desktop" ];
      };
    };

		# Fix for Dolphin to recognize Alacritty
    configFile."kdeglobals" = {
      text = ''
        [General]
        TerminalApplication=alacritty
        TerminalService=Alacritty.desktop
      '';
    };

		# Fix to allow kbuildsyscoca6 to build the menu database correctly
    configFile."menus/applications.menu".text = ''
      <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
        "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
      <Menu>
        <Name>Applications</Name>
        <DefaultAppDirs/>
        <DefaultDirectoryDirs/>
        <DefaultMergeDirs/>
      </Menu>
    '';
  };
}
