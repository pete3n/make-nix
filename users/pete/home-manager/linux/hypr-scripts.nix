# Helper scripts for hyprland config
{ pkgs, ... }:
let
  # Hyprland session restoration script
  hypr-session-restore =
    pkgs.writeShellScriptBin "hypr-session-restore" # sh
      ''
        tmux has-session -t 0 2>/dev/null || tmux new-session -s 0 -d
        hyprctl dispatch exec "[workspace 2] firefox"
        sleep 2
        hyprctl dispatch exec "[workspace 1] alacritty -e tmux attach -t 0"
        hyprctl dispatch workspace 1
      '';

	# Adapted from jason9075: https://github.com/jason9075/rofi-hyprland-keybinds-cheatsheet/tree/main
	rofi-hypr-cheatsheet = 
		pkgs.writeShellScriptBin "rofi-hypr-cheatsheet" #sh
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
								printf "<span color=%sgray%s>  %s</span>\n", q, q, cmd
							}
						'
				)

				choice="$(printf '%s\n' "''${bindings[@]}" | "rofi" -dmenu -i -markup-rows -p "Hyprland Keybinds:")"
				[ -n "$choice" ] || exit 0

				# Extract cmd from <span color='gray'>CMD</span>
				cmd="$(printf '%s\n' "$choice" | "$sed" -n 's/.*<span color='\'''gray'\'''> *\(.*\)<\/span>.*/\1/p')"
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
		hypr-session-restore
		rofi-hypr-cheatsheet
	];
}
