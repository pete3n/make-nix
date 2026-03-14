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
  fds = # sh
    ''
      fds() {
        local _rg_pattern=""
        local _use_fzf=0
        local _fd_ext=""
        local _fd_type="f"
        local _fd_pattern=""
        local _search_dir="."

        if [ -z "''${1:-}" ]; then
          printf "Usage: fds [OPTIONS] <fd-pattern> [search-dir]\n" >&2
          printf "  -r <pattern>   ripgrep through matched files\n" >&2
          printf "  -f             browse with fzf\n" >&2
          printf "  -e <ext>       filter by extension\n" >&2
          printf "  -t <type>      fd type filter (default: f)\n" >&2
          return 1
        fi

        while [ $# -gt 0 ]; do
          case "''${1}" in
            -r) _rg_pattern="''${2}"; shift 2 ;;
            -f) _use_fzf=1; shift ;;
            -e) _fd_ext="''${2}"; shift 2 ;;
            -t) _fd_type="''${2}"; shift 2 ;;
            -*) printf "fds: unknown option: %s\n" "''${1}" >&2; return 1 ;;
            *)
              if [ -z "''${_fd_pattern}" ]; then
                _fd_pattern="''${1}"
              else
                _search_dir="''${1}"
              fi
              shift
              ;;
          esac
        done

        if [ -z "''${_fd_pattern}" ]; then
          printf "fds: fd pattern required\n" >&2
          return 1
        fi

        _fd_base="${pkgs.fd}/bin/fd --type ''${_fd_type} --hidden --no-ignore"
        if [ -n "''${_fd_ext}" ]; then
          _fd_base="''${_fd_base} --extension ''${_fd_ext}"
        fi
        _fd_cmd="''${_fd_base} ''${_fd_pattern} ''${_search_dir}"

        if [ "''${_use_fzf}" -eq 1 ] && [ -n "''${_rg_pattern}" ]; then
          _selected=$(''${_fd_cmd} | ${pkgs.fzf}/bin/fzf --multi)
          if [ -z "''${_selected}" ]; then
            printf "fds: no files selected\n" >&2
            return 1
          fi
          printf "%s\n" "''${_selected}" | xargs -d '\n' ${pkgs.ripgrep}/bin/rg "''${_rg_pattern}"

        elif [ "''${_use_fzf}" -eq 1 ]; then
          ''${_fd_cmd} | ${pkgs.fzf}/bin/fzf --multi \
            --preview "${pkgs.bat}/bin/bat --color=always --line-range=:200 {} 2>/dev/null || head -200 {}" \
            --preview-window "right:60%"

        elif [ -n "''${_rg_pattern}" ]; then
          ''${_fd_cmd} -0 | xargs -0 ${pkgs.ripgrep}/bin/rg "''${_rg_pattern}"

        else
          ''${_fd_cmd}
        fi
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
			bind 'set show-mode-in-prompt on'
			bind 'set vi-ins-mode-string \1\e[32m\2[I]\1\e[0m\2 '
			bind 'set vi-cmd-mode-string \1\e[34m\2[N]\1\e[0m\2 '
      alias zf=zfile
    ''
    + tmux_preserve_path
    + sudo_wrapper
    + nix_path
    + smart_help
    + zfile
    + fds;

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
