{ pkgs, makeNixAttrs, ... }:
{
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

    dataFile."kservices6/ServiceMenus/open-alacritty-here.desktop".text = ''
      [Desktop Entry]
      Type=Service
      ServiceTypes=KonqPopupMenu/Plugin
      MimeType=inode/directory;
      Actions=OpenAlacrittyHere

      [Desktop Action OpenAlacrittyHere]
      Name=Open Alacritty Here
      Icon=utilities-terminal
      Exec=${pkgs.alacritty}/bin/alacritty --working-directory %f
    '';

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
  };
}
