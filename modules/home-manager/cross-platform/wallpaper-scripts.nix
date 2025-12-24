{
  config,
  pkgs,
  lib,
  makeNixAttrs,
  ...
}:
let
  cfg = config.programs.wallpaper-scripts;

  # Configure the appropriate command to set the wallpaper image for
  # both linux and darwin
  setCommand =
    if cfg.os == "darwin" then
      ''
        osascript -e "tell application \"System Events\" to set picture of every desktop to (POSIX file \"$wallpaper_path\")"
      ''
    else
      ''
        ${pkgs.swww}/bin/swww img "$wallpaper_path"
      '';

  # Set either the default wallpaper or a user-specified path
  wallpaperSetScript =
    pkgs.writeShellScriptBin "wallpaper-set"
      # bash
      ''
        wallpaper_path=${cfg.wallpaperPath}
        if [[ ! -f "$wallpaper_path" ]]; then
        	printf "Wallpaper not found at: %s\n" "''${wallpaper_path}"
        	exit 1
        fi

        ${setCommand}
      '';

  # Configure the appropriate command to get the current wallpaper image for
  # both linux and darwin
  getWallpaper =
    if cfg.os == "darwin" then
      ''
        osascript -e 'tell application "System Events" to get picture of desktop 1'
      ''
    else
      ''
        ${pkgs.swww}/bin/swww query | grep -oP 'image: \K.*' | head -n 1
      '';

  # Configure the appropriate command to set the wallpaper images for
  # both linux and darwin
  setNextCommand =
    if cfg.os == "darwin" then
      ''
        osascript -e "tell application \"System Events\" to set picture of every desktop to (POSIX file \"$next_wallpaper\")"
      ''
    else
      ''
        ${pkgs.swww}/bin/swww img --transition-step 20 --transition-fps 60 "$next_wallpaper"
      '';

  /*
       Find all supported image types in the same directory as the current wallpaper
    image. Sort them, and then call the setNextCommand to change to the next
    wallpaper image from the list
  */
  wallpaperCycleScript =
    pkgs.writeShellScriptBin "wallpaper-cycle"
      # sh
      ''
        types="jpeg jpg png gif bmp"
        wallpaper_dir="$(dirname "${cfg.wallpaperPath}")"
        current_wallpaper="$(${getWallpaper})"

        if [ -z "$current_wallpaper" ]; then
        	printf "No current wallpaper found.\n"
        	exit 1
        fi

        wallpaper_dir=$(dirname "$current_wallpaper")

        if [ ! -d "$wallpaper_dir" ]; then
        	printf "Wallpaper directory not found: %s\n" "''${wallpaper_dir}"
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
        	printf "No wallpaper files found in the directory.\n"
        	exit 1
        fi

        for i in "''${!sorted_files[@]}"; do
        	if [[ "''${sorted_files[i]}" == "$current_wallpaper" ]]; then
        		next_index=$(((i + 1) % ''${#sorted_files[@]}))
        		next_wallpaper=''${sorted_files[$next_index]}
        		break
        	fi
        done

        if [ -z "$next_wallpaper" ]; then
        	printf "Next wallpaper not found.\n"
        	exit 1
        fi
        ${setNextCommand}
      '';
in
{
  options.programs.wallpaper-scripts = {
    enable = lib.mkEnableOption "Wallpaper CLI scripts";

    os = lib.mkOption {
      type = lib.types.enum [
        "linux"
        "darwin"
      ];
      default = "linux";
      description = "Operating system type (linux or darwin)";
    };

    wallpaperPath = lib.mkOption {
      type = lib.types.path;
      description = ''Wallpaper image path'';
    };
  };

	# TODO: Implement XDG paths
  config = lib.mkIf cfg.enable {
    programs.wallpaper-scripts.wallpaperPath = lib.mkDefault (
      if config.programs.wallpaper-scripts.os == "darwin" then
        "/Users/${makeNixAttrs.user}/Pictures/wallpapers/default_background.png"
      else
        "/home/${makeNixAttrs.user}/Pictures/wallpapers/default_background.png"
    );
    home.packages = [
      wallpaperSetScript
      wallpaperCycleScript
    ];
  };
}
