{  makeNixAttrs, ... }:
{
  xdg = {
    enable = true;
    portal = {
      enable = true;
      xdgOpenUsePortal = true;
      config = {
        common = {
          default = [
            "hyprland"
          ];
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
        XDG_AUDIO_DIR = "/home/${makeNixAttrs.user}/Audio";
      };
    };

  };
}
