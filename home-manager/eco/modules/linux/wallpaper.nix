{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  cfgWallpaper = config.programs.wallpaper;
in {
  options.programs.wallpaper = with lib; {
    enable = mkEnableOption "Wallpapaer management";

    wallpaper = mkOption {
      default = "/home/user/wallpapers/default_background.png"; #Template to enforce path type
      type = types.path;
      description = ''Wallpaper image path'';
    };
  };
  config = lib.mkIf cfgWallpaper.enable {
    home.packages = with pkgs; [
      (let
        wallpaperSetScript = writeShellScriptBin "wallpaper-set" ''
             	#!/bin/bash
          defaultWallpaperPath="/home/user/wallpapers/default_background.png"
          wallpaperPath=${cfgWallpaper.wallpaper}
          if [ "$wallpaperPath" == "$defaultWallpaperPath" ]; then
          	wallpaperPath="''${HOME}/wallpapers/default_background.png"
          fi
          swww img "$wallpaperPath"
        '';
      in
        wallpaperSetScript)

      (writeShellScriptBin "wallpaper-cycle" ''
        #!/bin/bash
            # swww supported file types as of version 0.8.1
            types="jpeg jpg png gif pnm tga tiff tif webp bmp farbfeld"

            # Get the wallpaper director used by the first display showing a wallpaper
            current_wallpaper=$(swww query | grep -oP 'image: \K.*' | head -n 1)

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

            swww img --transition-step 20 --transition-fps 60 "$next_wallpaper"
      '')
    ];
  };
}
