{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    blender # 3D modelling
    ffmpeg # Video encoding/transcoding
    gimp-with-plugins # Image editing
    handbrake # DVD wripping
    helvum # Audio patch panel for pipewire
    mpc-cli # MPD CLI
    mpd # Music player daemon
    ncmpcpp # N-curses music player client plus-plus
    pavucontrol # Pulse audio volume control
    shotcut # Video editing
    vlc # Videolan client
    yt-dlp # Youtube download Python
  ];
}
