{ pkgs, ... }:
let
  # Hyprland session restoration script
  rofi-help-menu =
    pkgs.writeShellScriptBin "rofi-help-menu" # sh
      ''
        set -eu

        sed="${pkgs.gnused}/bin/sed"
        rofi="${pkgs.rofi}/bin/rofi"

        # Providers on PATH (installed by home.packages)
        providers="
        Hyprland|rofi-help-hypr
        Tmux|rofi-help-tmux
        "

        pick_provider="$(
          printf '%s\n' "$providers" \
          | "$sed" 's/|.*//' \
          | "$rofi" -dmenu -i -p "Help:"
        )"
        [ -n "$pick_provider" ] || exit 0

        provider_cmd="$(printf '%s\n' "$providers" | "$sed" -n "s/^$pick_provider|\(.*\)$/\1/p")"
        [ -n "$provider_cmd" ] || exit 1

        choice="$("$provider_cmd" | "$rofi" -dmenu -i -markup-rows -p "$pick_provider:")"
        [ -n "$choice" ] || exit 0

        cmd="$(printf '%s\n' "$choice" | "$sed" -n 's/.*<span color='\'''#dddddd'\'''> *\(.*\)<\/span>.*/\1/p')"
        [ -n "$cmd" ] || exit 0

        # Very simple dispatch policy:
        # - "tmux:" prefix => run inside tmux if possible, else spawn terminal
        # - otherwise => run as shell
        case "$cmd" in
          tmux:*)
            tmux_cmd="''${cmd#tmux:}"
            if [ -n "''${TMUX-}" ]; then
              tmux $tmux_cmd
            else
              ${pkgs.alacritty}/bin/alacritty -e ${pkgs.tmux}/bin/tmux $tmux_cmd
            fi
            ;;
          *)
            ${pkgs.bash}/bin/bash -lc "$cmd"
            ;;
        esac

      '';

	# Adapted from jason9075: https://github.com/jason9075/rofi-hyprland-keybinds-cheatsheet/tree/main
	rofi-help-hypr = 
		pkgs.writeShellScriptBin "rofi-help-hypr" #sh
			''
				set -eu
				awk="${pkgs.gawk}/bin/awk"
				sed="${pkgs.gnused}/bin/sed"
				grep="${pkgs.gnugrep}/bin/grep"

				config_dir="''${XDG_CONFIG_HOME:-"$HOME/.config"}"
				hypr_conf="$config_dir/hypr/hyprland.conf"

				if [ ! -f "$hypr_conf" ]; then
					printf 'Hyprland config not found: %s\n' "$hypr_conf" >&2
					exit 1
				fi

				# Pull bind lines, normalize spaces, then format as Pango markup:
				# <b>MOD + KEY</b>  <i>desc</i><span color='gray'>CMD</span>
				mapfile -t bindings < <(
					"$grep" -E '^[[:space:]]*bind[[:space:]]*=' "$hypr_conf" \
					| "$sed" -E 's/[[:space:]]+/ /g; s/^[[:space:]]*bind[[:space:]]*=[[:space:]]*//; s/, /,/g' \
					| "$awk" -F, -v q="'" '
							function esc(s) {
								gsub(/&/, "\\&amp;", s)
								gsub(/</, "\\&lt;", s)
								gsub(/>/, "\\&gt;", s)
								return s
							}
							{
								line = $0

								# If there is a comment (#...), split it off as desc; otherwise desc empty
								desc = ""
								hash = index(line, "#")
								if (hash > 0) {
									desc = substr(line, hash+1)
									sub(/^[[:space:]]+/, "", desc)
									line = substr(line, 1, hash-1)
									sub(/[[:space:]]+$/, "", line)
								}

								# Re-split the non-comment portion into fields
								n = split(line, a, ",")

								if (n < 3) next

								mod = a[1]
								key = a[2]

								cmd = ""
								for (i = 3; i <= n; i++) {
									cmd = cmd a[i]
									if (i != n) cmd = cmd ","
								}

								# Escape for Pango markup
								mod = esc(mod); key = esc(key); desc = esc(desc); cmd = esc(cmd)

								printf "<b>%s + %s</b>", mod, key
								if (desc != "") printf "  <i>%s</i>", desc
								printf "<span color=%s#dddddd%s>  %s</span>\n", q, q, cmd
							}
						'
				)

				choice="$(printf '%s\n' "''${bindings[@]}" | "rofi" -dmenu -i -markup-rows -p "Hyprland Keybinds:")"
				[ -n "$choice" ] || exit 0

				# Extract cmd from <span color='gray'>CMD</span>
				cmd="$(printf '%s\n' "$choice" | "$sed" -n 's/.*<span color='\'''#dddddd'\'''> *\(.*\)<\/span>.*/\1/p')"
				[ -n "$cmd" ] || exit 0

				if [[ "$cmd" == exec* ]]; then
					# drop leading "exec" + optional spaces
					rest="''${cmd#exec}"
					rest="''${rest# }"
					${pkgs.bash}/bin/bash -lc "$rest"
				else
					"hyprctl" dispatch $cmd
				fi
			'';
in
{
  home.packages = [
    rofi-help-menu
		rofi-help-hypr
  ];
}
