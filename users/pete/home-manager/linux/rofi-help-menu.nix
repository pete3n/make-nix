{ pkgs, ... }:
let
  # Hyprland session restoration script
  rofi-help-menu =
    pkgs.writeShellScriptBin "rofi-help-menu" # sh
      ''
				set -eu

				rofi="${pkgs.rofi}/bin/rofi"
				sed="${pkgs.gnused}/bin/sed"
				bash="${pkgs.bash}/bin/bash"
				hyprctl="${pkgs.hyprland}/bin/hyprctl"


				CMD_COLOR="#dddddd"

				mode="root"

				while :; do
					case "$mode" in
						root)
							prompt="Help:"
							entries=$(
								printf '%s\n' \
									"<b>Hyprland - Enter for Hyprland keymap help</b><span color='$CMD_COLOR'>  __menu__:hypr</span>" \
									"<b>Tmux - Enter for Tmux keymap help</b><span color='$CMD_COLOR'>  __menu__:tmux</span>"
							)
							;;
						hypr)
							prompt="Hyprland:"
							entries=$(
								printf '%s\n' "<b>← Enter to go back</b><span color='$CMD_COLOR'>  __menu__:root</span>"
								rofi-help-hypr   # IMPORTANT: provider prints rows ONLY
							)
							;;
						tmux)
							prompt="Tmux:"
							entries=$(
								printf '%s\n' "<b>← Back</b><span color='$CMD_COLOR'>  __menu__:root</span>"
								rofi-help-tmux   # provider prints rows ONLY
							)
							;;
						*)
							mode="root"
							continue
							;;
					esac

					choice="$(printf '%s\n' "$entries" | "$rofi" -dmenu -i -markup-rows -p "$prompt")"
					[ -n "$choice" ] || exit 0

					cmd="$(printf '%s\n' "$choice" | "$sed" -n 's/.*<span color='\'''#dddddd'\'''> *\(.*\)<\/span>.*/\1/p')"
					[ -n "$cmd" ] || continue

					case "$cmd" in
						__menu__:root) mode="root" ;;
						__menu__:hypr) mode="hypr" ;;
						__menu__:tmux) mode="tmux" ;;
						*)
							case "$mode" in
								hypr)
									printf 'DEBUG mode=%s cmd=[%s]\n' "$mode" "$cmd" >&2
									if [[ "$cmd" == exec* ]]; then
										rest="''${cmd#exec}"
										rest="''${rest# }"
										"$bash" -lc "$rest"
									else
										"$hyprctl" dispatch "$cmd"
									fi
									;;
								tmux)
									# whatever you decide for tmux
									"$bash" -lc "$cmd"
									;;
								*)
									"$bash" -lc "$cmd"
									;;
							esac
							;;
					esac
				done
      '';

  # Adapted from jason9075: https://github.com/jason9075/rofi-hyprland-keybinds-cheatsheet/tree/main
  rofi-help-hypr =
    pkgs.writeShellScriptBin "rofi-help-hypr" # sh
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

                # Print rows ONLY. The hub script will run rofi and handle back/dispatch.
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

        						# comment -> desc
        						desc = ""
        						hash = index(line, "#")
        						if (hash > 0) {
        							desc = substr(line, hash+1)
        							sub(/^[[:space:]]+/, "", desc)
        							line = substr(line, 1, hash-1)
        							sub(/[[:space:]]+$/, "", line)
        						}

        						n = split(line, a, ",")
        						if (n < 3) next

        						mod = a[1]
        						key = a[2]

        						cmd = ""
        						for (i = 3; i <= n; i++) {
        							cmd = cmd a[i]
        							if (i != n) cmd = cmd " "
        						}

        						mod = esc(mod); key = esc(key); desc = esc(desc); cmd = esc(cmd)

        						printf "<b>%s + %s</b>", mod, key
        						if (desc != "") printf "  <i>%s</i>", desc
        						printf "<span color=%s#dddddd%s>  %s</span>\n", q, q, cmd
        					}
        				'
        			'';

  rofi-help-tmux =
    pkgs.writeShellScriptBin "rofi-help-tmux" # sh
      ''
        set -eu
				awk="${pkgs.gawk}/bin/awk"
				tmux="${pkgs.tmux}/bin/tmux"

				# Require server running (your chosen behavior)
				if ! "$tmux" ls >/dev/null 2>&1; then
					printf "<b>tmux not running</b>  <i>start default session</i><span color='#dddddd'>  tmux new-session -A -s 0</span>\n"
					exit 0
				fi

				# Prefer list-keys (shows effective binds)
				out="$("$tmux" list-keys 2>/dev/null || true)"
				if [ -z "$out" ]; then
					printf "<b>No keybinds returned</b><span color='#dddddd'>  echo 'tmux list-keys produced no output'</span>\n"
					exit 0
				fi

				printf '%s\n' "$out" \
					| "$awk" -v q="'" '
							function esc(s) {
								gsub(/&/, "\\&amp;", s)
								gsub(/</, "\\&lt;", s)
								gsub(/>/, "\\&gt;", s)
								return s
							}

							# Split a line into tokens by spaces, preserving quoted strings as single tokens.
							# tmux output can include quoted args (e.g., run-shell "foo bar").
							function tokenize(s, a,    i, n, c, tok, inq) {
								n = 0; tok = ""; inq = 0
								for (i = 1; i <= length(s); i++) {
									c = substr(s, i, 1)
									if (c == "\"") { inq = !inq; tok = tok c; continue }
									if (!inq && c == " ") {
										if (tok != "") { a[++n] = tok; tok = "" }
										continue
									}
									tok = tok c
								}
								if (tok != "") a[++n] = tok
								return n
							}

							{
								line = $0
								sub(/^[[:space:]]+/, "", line)
								if (line == "") next

								# Accept bind / bind-key
								if (line !~ /^(bind|bind-key)[[:space:]]/) next

								# Normalize whitespace
								gsub(/[[:space:]]+/, " ", line)

								# Tokenize (preserve quoted strings)
								n = tokenize(line, t)
								if (n < 3) next

								# Defaults
								table = "root"
								key = ""
								cmd_start = 0

								# Walk tokens, skip known flags, capture -T table and find key
								# Typical forms:
								# bind-key -T prefix c new-window
								# bind -n M-Left previous-window
								i = 2
								while (i <= n) {
									if (t[i] == "-T" && i+1 <= n) { table = t[i+1]; i += 2; continue }
									if (t[i] == "-n" || t[i] == "-r") { i += 1; continue }
									# Some tmux versions include -N "note" in list-keys, keep it if present as tokens
									if (t[i] == "-N" && i+1 <= n) { i += 2; continue }

									# First non-flag token after options is key
									key = t[i]
									cmd_start = i + 1
									break
								}

								if (key == "" || cmd_start == 0 || cmd_start > n) next

								# Rebuild command (everything after key) exactly as tokens
								cmd = ""
								for (j = cmd_start; j <= n; j++) {
									cmd = cmd t[j]
									if (j < n) cmd = cmd " "
								}
								if (cmd == "") next

								# Display label
								table_esc = esc(table)
								key_esc   = esc(key)
								disp = "<b>" table_esc "  " key_esc "</b>"

								action = esc("tmux " cmd)
								printf "%s<span color=%s#dddddd%s>  %s</span>\n", disp, q, q, action
							}
						'
        	'';
in
{
  home.packages = [
    rofi-help-menu
    rofi-help-hypr
		rofi-help-tmux
  ];
}
