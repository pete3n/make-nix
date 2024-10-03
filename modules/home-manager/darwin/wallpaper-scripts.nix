{
  config,
  pkgs,
  lib,
  ...
}: let
  cfgWallpaper = config.programs.wallpaper-scripts;
in {
  options.programs.wallpaper-scripts = {
    enable = lib.mkEnableOption "Wallpaper management for macOS";

    wallpaperPath = lib.mkOption {
      default = "${config.home.homeDirectory}/wallpapers/default_background.png"; # Template path
      type = lib.types.path;
      description = "Wallpaper image path";
    };
  };

  config = lib.mkIf cfgWallpaper.enable {
    home.packages = [
      # Wallpaper set script
      (let
        wallpaperSetScript =
          pkgs.writeShellScriptBin "wallpaper-set"
          /*
          bash
          */
          ''
            wallpaper_path=${cfgWallpaper.wallpaperPath}
            if [[ ! -f "$wallpaper_path" ]]; then
              echo "Wallpaper not found at $wallpaper_path"
              exit 1
            fi
            # Use osascript to set the wallpaper on all desktops
            osascript -e "tell application \"System Events\" to set picture of every desktop to (POSIX file \"$wallpaper_path\")"
          '';
      in
        wallpaperSetScript)

      # Wallpaper cycle script
      (pkgs.writeShellScriptBin "wallpaper-cycle"
        /*
        bash
        */
        ''
          types="jpeg jpg png gif bmp"
          wallpaper_dir="$(dirname "${cfgWallpaper.wallpaperPath}")"
          current_wallpaper="$(osascript -e 'tell application "System Events" to get picture of desktop 1')"

               if [ -z "$current_wallpaper" ]; then
               	echo "No current wallpaper found."
               	exit 1
               fi

               wallpaper_dir=$(dirname "$current_wallpaper")

               if [ ! -d "$wallpaper_dir" ]; then
               	echo "Wallpaper directory not found: $wallpaper_dir"
               	exit 1
               fi

               files=()
               for type in $types; do
               	while IFS= read -r -d '''''' file; do
               		files+=("$file")
               	done < <(find "$wallpaper_dir" -maxdepth 1 -type f -name "*.$type" -print0)
               done

               mapfile -t sorted_files < <(printf '%s\n' "''${files[@]}" | sort)

               unset IFS

               if [ ''${#sorted_files[@]} -eq 0 ]; then
               	echo "No wallpaper files found in the directory."
               	exit 1
               fi

          # Find the current wallpaper in the sorted list and get the next one
          for i in "''${!sorted_files[@]}"; do
          	if [[ "''${sorted_files[i]}" == "$current_wallpaper" ]]; then
          		next_index=$(((i + 1) % ''${#sorted_files[@]}))
          		next_wallpaper=''${sorted_files[$next_index]}
          		break
          	fi
          done

          if [ -z "$next_wallpaper" ]; then
          	echo "Next wallpaper not found."
          	exit 1
          fi
          osascript -e "tell application \"System Events\" to set picture of every desktop to (POSIX file \"$next_wallpaper\")"
        '')
    ];
  };
}
