{
  lib,
  pkgs,
  makeNixAttrs,
  makeNixLib,
  ...
}:
{
  home.packages = with pkgs; [
    desktop-file-utils
    kdePackages.kservice # provides kbuildsycoca6
    kdePackages.kio-extras
    kdePackages.kmenuedit
  ];
  xdg.enable = true;
  xdg.portal = {
    enable = true;
    # https://github.com/nix-community/home-manager/issues/7124
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ]
    ++ lib.optionals (makeNixLib.hasTag "hyprland" makeNixAttrs.tags) [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
    xdgOpenUsePortal = true;
    config.common.default =
      if (makeNixLib.hasTag "hyprland" makeNixAttrs.tags) then
        [
          "hyprland"
          "gtk"
        ]
      else
        [ "gtk" ];
  };

  xdg.configFile."xdg-desktop-portal/hyprland-portals.conf" =
    lib.mkIf (makeNixLib.hasTag "hyprland" makeNixAttrs.tags)
      {
        text = ''
          [preferred]
          default=hyprland;gtk
          org.freedesktop.impl.portal.FileChooser=kde
          org.freedesktop.impl.portal.Settings=gtk
        '';
      };

  xdg.userDirs = {
    enable = true;
    setSessionVariables = true;
    documents = "/home/${makeNixAttrs.user}/Documents";
    download = "/home/${makeNixAttrs.user}/Downloads";
    music = "/home/${makeNixAttrs.user}/Music";
    pictures = "/home/${makeNixAttrs.user}/Pictures";
    publicShare = "/home/${makeNixAttrs.user}/Public";
    templates = "/home/${makeNixAttrs.user}/Templates";
    videos = "/home/${makeNixAttrs.user}/Videos";

    extraConfig = {
      PROJECT = "/home/${makeNixAttrs.user}/Projects";
    };
  };

  xdg.mimeApps = {
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
  xdg.configFile."kdeglobals" = {
    text = ''
      [General]
      TerminalApplication=alacritty
      TerminalService=Alacritty.desktop
    '';
  };

  # Fix to allow kbuildsyscoca6 to build the menu database correctly
  xdg.configFile."menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
    </Menu>
  '';
}
