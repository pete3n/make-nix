{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;

  cfg = config.services.zoeyChar;

  zoey-char-daemon =
    pkgs.writeShellScriptBin "zoey-char-daemon" # sh
      ''
        #!/usr/bin/env bash

        CHAR_IMG_DIR="${cfg.imageDir}"
        CHAR_AUDIO_DIR="${cfg.audioDir}"
        PIPE="${"$"}{XDG_RUNTIME_DIR}/zoey_char.pipe"
        SWAYIMG_PID=""
        PAPLAY_PID=""

        cleanup() {
          close_char
          rm -f "${"$"}{PIPE}"
          exit 0
        }

        close_char() {
          [ -n "${"$"}{SWAYIMG_PID}" ] && ${pkgs.util-linux}/bin/kill "${"$"}{SWAYIMG_PID}" 2>/dev/null || true
          [ -n "${"$"}{PAPLAY_PID}" ] && ${pkgs.util-linux}/bin/kill "${"$"}{PAPLAY_PID}" 2>/dev/null || true
          SWAYIMG_PID=""
          PAPLAY_PID=""
        }

        show_char() {
          _char="${"$"}{1:-}"
          _img="${"$"}{CHAR_IMG_DIR}/${"$"}{_char}.jpg"
          _audio="${"$"}{CHAR_AUDIO_DIR}/${"$"}{_char}.wav"

          close_char

          if [ -f "${"$"}{_img}" ]; then
            ${pkgs.swayimg}/bin/swayimg --class char-popout --scale fit -c info.show=no "${"$"}{_img}" &
            SWAYIMG_PID=$!
          fi

          if [ -f "${"$"}{_audio}" ]; then
            ${pkgs.pulseaudio}/bin/paplay "${"$"}{_audio}" &
            PAPLAY_PID=$!
          fi
        }

        trap cleanup EXIT INT TERM

        [ -p "${"$"}{PIPE}" ] || ${pkgs.coreutils}/bin/mkfifo "${"$"}{PIPE}"

        exec 3<>"${"$"}{PIPE}"
        while true; do
          if read -r -t ${toString cfg.displayDuration} char <&3; then
            show_char "$char"
          else
            close_char
          fi
        done
      '';

  zoey-char =
    pkgs.writeShellScriptBin "zoey-char" # sh
      ''
        #!/usr/bin/env bash

        PIPE="''${XDG_RUNTIME_DIR}/zoey_char.pipe"

        # No arguments - show greeting
        if [ $# -eq 0 ]; then
          timeout=10
          while [ ! -p "''${PIPE}" ] && [ "''${timeout}" -gt 0 ]; do
            sleep 0.5
            timeout=$(( timeout - 1 ))
          done
          printf '%s\n' "greeting" > "''${PIPE}"
          exit 0
        fi

        while getopts "c:" opt; do
          case "$opt" in
            c) printf '%s\n' "$OPTARG" > "''${PIPE}" ;;
            *) exit 1 ;;
          esac
        done      
      '';
in
{
  options.services.zoeyChar = {
    enable = mkEnableOption "Zoey character display daemon";

    displayDuration = mkOption {
      type = types.ints.positive;
      default = 4;
      description = ''
        Seconds to display a character image before auto-closing.
        Resets on each new keypress.
      '';
    };

    imageDir = mkOption {
      type = types.str;
      default = "${config.xdg.userDirs.pictures}/chars";
      description = ''
        Directory containing character image files.
        Expected format: <imageDir>/<char>.jpg
      '';
    };

    audioDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/Audio/chars";
      description = ''
        Directory containing character audio files.
        Expected format: <audioDir>/<char>.wav
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      zoey-char-daemon
      zoey-char
      pkgs.swayimg
      pkgs.pulseaudio
    ];

    systemd.user.services.zoey-char = {
      Unit = {
        Description = "Zoey character display daemon";
      };
      Service = {
        Type = "simple";
        ExecStart = "${zoey-char-daemon}/bin/zoey-char-daemon";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
