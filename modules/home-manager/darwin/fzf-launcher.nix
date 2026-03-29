{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.fzf-launcher;

  fzf-launcher = pkgs.writeShellScriptBin "fzf-launcher" # bash
    ''
      #!/usr/bin/env bash

      _apps=$(
        find /Applications /System/Applications ~/Applications \
          -maxdepth 2 -name "*.app" -type d 2>/dev/null \
          | sed 's|.*/||; s|\.app$||' \
          | sort -u
      )

      _selection=$(printf '%s\n' "$_apps" | \
        ${pkgs.fzf}/bin/fzf \
          --prompt="${cfg.prompt}" \
          --layout=reverse \
          --border \
          --height="${cfg.height}" \
          --no-multi)

      [ -n "$_selection" ] && open -a "$_selection"
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

    searchPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/Applications"
        "/System/Applications"
        "~/Applications"
      ];
      description = "Paths to search for .app bundles";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ fzf-launcher ];
  };
}
