{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.fzf-launcher;

  fzf-launcher =
    pkgs.writeShellScriptBin "fzf-launcher" # bash
      ''
        #!/usr/bin/env bash

        _nix_bin="$HOME/.nix-profile/bin"

        _apps=$(
        	{
        		find -L \
        			/Applications \
        			/System/Applications \
        			-maxdepth 2 -name "*.app" -type d 2>/dev/null \
        			| sed 's|.*/||; s|\.app$||'
        		find -L \
        			"$HOME/Applications/Home Manager Apps" \
        			-maxdepth 1 -name "*.app" -type d 2>/dev/null \
        			| sed 's|.*/||; s|\.app$||'
        		find -L \
        			"$_nix_bin" \
        			/run/current-system/sw/bin \
        			-maxdepth 1 \( -type f -o -type l \) 2>/dev/null \
        			| sed 's|.*/||'
        	} | sort -u
        )

        _selection=$(printf '%s\n' "$_apps" | \
          ${pkgs.fzf}/bin/fzf \
            --prompt="${cfg.prompt}" \
            --layout=reverse \
            --border \
            --height="${cfg.height}" \
            --no-multi \
            --print-query \
            | tail -1)

        [ -n "$_selection" ] || exit 0

        _cmd=$(printf '%s' "$_selection" | cut -d' ' -f1)
        _args=$(printf '%s' "$_selection" | cut -d' ' -f2-)

        if [ -f "$_nix_bin/$_cmd" ] || [ -L "$_nix_bin/$_cmd" ]; then
          open -n ${pkgs.alacritty}/Applications/Alacritty.app \
            --args -e /bin/sh -c \
            "source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; \
             source $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh; \
             exec $_nix_bin/$_cmd $_args"
        else
          open -a "$_cmd"
        fi
      '';
in
{
  options.programs.fzf-launcher = {
    enable = lib.mkEnableOption "FZF application launcher for macOS";

    prompt = lib.mkOption {
      type = lib.types.str;
      default = "Launch: ";
      description = "Prompt string displayed in the FZF interface";
    };

    height = lib.mkOption {
      type = lib.types.str;
      default = "40%";
      description = "Height of the FZF launcher window";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ fzf-launcher ];
  };
}
