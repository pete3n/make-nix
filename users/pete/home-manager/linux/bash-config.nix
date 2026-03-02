# Bash HM configuraiton and extra config not provided by the HM module
{
  config,
  lib,
  pkgs,
  makeNixAttrs,
  ...
}:
let
  tmux_preserve_path =
    lib.optionalString makeNixAttrs.isHomeAlone # sh
      ''
        # For Home-alone Linux systems preserve PATH for tmux.
        # Determine path to store saved PATH
        if [ -n "$XDG_STATE_HOME" ]; then
        	PATH_STATE_DIR="$XDG_STATE_HOME"
        else
        	PATH_STATE_DIR="$HOME/.local/state"
        fi

        PATH_STATE_FILE="$PATH_STATE_DIR/.nix-path.env"

        # Ensure the directory exists
        mkdir -p "$PATH_STATE_DIR"

        # If not inside tmux, save the current PATH if it differs from the saved one
        if [ -z "$TMUX" ]; then
        	if [ -f "$PATH_STATE_FILE" ]; then
        		SAVED_PATH=$(grep '^PATH=' "$PATH_STATE_FILE" | cut -d'"' -f2)
        	else
        		SAVED_PATH=""
        	fi

        	if [ "$PATH" != "$SAVED_PATH" ]; then
        		printf 'PATH="%s"\nexport PATH\n' "$PATH" >"$PATH_STATE_FILE"
        	fi
        else
        	# Inside tmux: restore PATH if it doesn't match the saved one
        	if [ -f "$PATH_STATE_FILE" ]; then
        		SAVED_PATH=$(grep '^PATH=' "$PATH_STATE_FILE" | cut -d'"' -f2)

        		if [ "$PATH" != "$SAVED_PATH" ]; then
        			eval "$(cat "$PATH_STATE_FILE")"
        		fi
        	fi
        fi
      '';
  sudo_wrapper =
    lib.optionalString makeNixAttrs.isHomeAlone # sh
      ''
        # sudo wrapper do workaround missing path for commands when run as sudo
        sudo() {
        	if [ $# -eq 0 ]; then
        		command sudo
        	else
        		cmd=$(realpath "$(command -v "$1")")
        		shift
        		command sudo "$cmd" "$@"
        	fi
        }
      '';
  nix_path = # sh
    ''
      nixpath() {
        if [ -z "''${1:-}" ]; then
          printf "Usage: nixpath <binary>\n" >&2
          return 1
        fi
        printf "%s\n" "$(realpath "$(command -v "''${1}")")"
      }
    '';
  smart_help = # sh
    ''
      smart_help() {
      if [ -z "''${1:-}" ]; then
      	printf "Usage: ? <command|topic|question>\n" >&2
      	return 1
      fi

      NIX_CURL="${pkgs.curl}/bin/curl"
      NIX_JQ="${pkgs.jq}/bin/jq"
      NIX_DDGR="${pkgs.ddgr}/bin/ddgr"
      NIX_SED="${pkgs.gnused}/bin/sed"

      ${pkgs.tldr}/bin/tldr "$@" && return 0

      _query_plus="$(printf '%s' "$*" | tr ' ' '+')"
      _query_url="$(printf '%s' "$*" | $NIX_SED 's/ /%20/g')"

      printf "tldr not found for '%s', checking cheat.sh...\n" "$*" >&2
      _cheat_out="$(
      "$NIX_CURL" --silent --max-time 10 \
      "https://cheat.sh/''${_query_plus}"
      )" || _cheat_out=""

      # Strip ANSI escape codes for plain-text detection only
      # Regex matches ESC[ followed by numeric params and a letter command
      _ansi_strip_pattern='s/\x1b\[[0-9;]*[a-zA-Z]//g'
      _cheat_plain="$(printf '%s\n' "''${_cheat_out}" | $NIX_SED "''${_ansi_strip_pattern}")"

      # cheat.sh always returns HTTP 200 — detect failure by body content
      # 404 response is a CSS comment block containing "Unknown cheat sheet"
      if printf '%s\n' "''${_cheat_plain}" | ${pkgs.gnugrep}/bin/grep -qF "Unknown cheat sheet"; then
      	_cheat_out=""
      fi

      if [ -n "''${_cheat_out:-}" ]; then
      	printf '%s\n' "''${_cheat_out}"
      	return 0
      fi

      printf "Checking DuckDuckGo instant answers...\n" >&2
      _ddg_json="$(
      "$NIX_CURL" --silent --max-time 10 \
      --user-agent "smart_help/1.0 (terminal helper)" \
      "https://api.duckduckgo.com/?q=''${_query_url}&format=json&no_html=1&skip_disambig=1"
      )" || { printf "DEBUG curl failed\n" >&2; _ddg_json=""; }

      _ddg_out="$(printf '%s\n' "''${_ddg_json}" | "$NIX_JQ" -r '
      if .AbstractText and .AbstractText != "" then
      "[\(.AbstractSource)]\n\(.AbstractText)"
      elif .Answer and .Answer != "" then
      "[Instant Answer]\n\(.Answer)"
      elif (.RelatedTopics | length) > 0 then
      "[Related]\n" + (
      [ .RelatedTopics[]
      | select(.Text)
      | "- \(.Text)"
      ] | .[0:5] | join("\n")
      )
      else "" end
      ')"
      if [ -n "''${_ddg_out:-}" ]; then
      	printf '%s\n' "''${_ddg_out}"
      	return 0
      fi

      printf "Searching DuckDuckGo...\n" >&2
      "''${NIX_DDGR}" --noprompt "$@"
      }
      alias "?"=smart_help
    '';
  zfile = # sh
    ''
      zfile() {
      if [ -z "''${1:-}" ]; then
      	printf "Usage: zfile <filename>\n" >&2
      	return 1
      fi 
      _match=$("${pkgs.fd}/bin/fd" --type f "''${1}" | head -n 1)
      if [ -z "''${_match}" ]; then
      	printf "zfile: no file found matching '%s'\n" "''${1}" >&2
      	return 1
      fi
      z "$(dirname "$_match")"
      }
    '';
in
{
  programs.bash = {
    enableCompletion = true;
    shellAliases = {
      cd = "z";
      home-manager-rollback = "home-manager generations | fzf | awk -F '-> ' '{print \$2 \"/activate\"}'";
      lsc = "lsd --classic";
      ns = "nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history";
      screenshot = "grim";
    };
    initExtra = # sh
    ''
			set -o vi
			alias zf=zfile
    ''
    + tmux_preserve_path
    + sudo_wrapper
    + nix_path
    + smart_help
    + zfile;

    profileExtra = # sh
      ''
        export EDITOR=nvim
        if [ -z "$FASTFETCH_EXECUTED" ] && [ -z "$TMUX" ]; then
        	command -v fastfetch &> /dev/null && fastfetch
        	export FASTFETCH_EXECUTED=1
        	printf "\n"	
        	ip link
        	printf "\n"
        	ip -br a
        	printf "\n"
        fi
        # Workaround for xdg.userDirs bug always being set to false
        source "${config.home.homeDirectory}/.config/user-dirs.dirs"
      '';
  };
}
