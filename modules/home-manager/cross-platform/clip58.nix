{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.clip58;

  # TODO FIX: Ninjection Issue #15
  clip58Script = pkgs.writeShellScriptBin "clip58" (
    if pkgs.stdenv.isDarwin then # sh
      ''
        #!/usr/bin/env sh
        set -eu
        if [ $# -ne 1 ]; then
        	printf "Usage: clip58 <string>" >&2
        	exit 1
        fi
        encoded=$(printf "%s" "$1" | base58)
        printf "%s" "$encoded" | pbcopy
        printf "%s\n" "$encoded"
      ''
    else
    # sh
      ''
        #!/usr/bin/env sh
        set -eu
        if [ $# -ne 1 ]; then
          echo "Usage: clip58 <string>" >&2
          exit 1
        fi
        encoded=$(printf "%s" "$1" | base58)
        if command -v wl-copy >/dev/null 2>&1; then
          printf "%s" "$encoded" | wl-copy
        elif command -v xclip >/dev/null 2>&1; then
          printf "%s" "$encoded" | xclip -selection clipboard
        else
          printf "error: No clipboard tool found (wl-copy or xclip required)" >&2
          exit 2
        fi
        printf "%s\n" "$encoded"
      ''
  );
in
{
  options.programs.clip58 = {
    enable = lib.mkEnableOption "Install the clip58 clipboard encoder";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ clip58Script ];
  };
}
