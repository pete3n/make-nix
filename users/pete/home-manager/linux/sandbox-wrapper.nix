{ pkgs, ... }:
let
  sandboxLog = pkgs.writeShellScriptBin "sandboxed-log" ''
    set -eu
    KEY="''${1:-sandbox-}"
    SINCE="''${2:-today}"

    sudo ${pkgs.audit}/bin/ausearch \
      -k "$KEY" \
      --start "$SINCE" \
      --raw \
      2>/dev/null \
    | ${pkgs.gawk}/bin/awk '
      function emit(    dst, port) {
        if (evt_exe == "") return
        if (evt_exit != "-115" && evt_exit != "-111") return
        if (evt_exe !~ /^\/nix\/store\//) return
        if (evt_saddr != "" && evt_saddr ~ /laddr=127\.|laddr=::1|saddr_fam=local/) return
        # Only show per-run dynamic keys (sandbox-<binary>-YYYYMMDD-HHMMSS);
        # filters out legacy static keys like sandbox-connect
        if (evt_key !~ /^sandbox-[^-]+-[0-9]{8}-[0-9]{6}$/) return

        if (evt_saddr != "") {
          dst  = evt_saddr; gsub(/.*laddr=/, "", dst);  gsub(/ .*/,      "", dst)
          port = evt_saddr; gsub(/.*lport=/, "", port); gsub(/[^0-9].*/, "", port)
        } else {
          dst = "unknown"; port = "?"
        }

        printf "BLOCKED  %s\n  key=%s\n  pid=%-7s  comm=%s\n  dest=%s:%s\n  exe=%s\n\n",
          evt_time, evt_key, evt_pid, evt_comm, dst, port, evt_exe
      }

      /type=SYSCALL/ {
        emit()
        evt_exe=""; evt_comm=""; evt_pid=""
        evt_exit=""; evt_saddr=""; evt_time=""; evt_key=""
        match($0, /msg=audit\(([^)]+)\)/, m); evt_time = m[1]
        match($0, /exit=([^ ]+)/,         m); evt_exit = m[1]
        match($0, /pid=([^ ]+)/,           m); evt_pid  = m[1]
        match($0, /comm="([^"]+)"/,        m); evt_comm = m[1]
        match($0, /exe="([^"]+)"/,         m); evt_exe  = m[1]
        match($0, /key="([^"]+)"/,         m); evt_key  = m[1]
      }
      /type=SOCKADDR/ {
        match($0, /SADDR=\{([^}]+)\}/, m); evt_saddr = m[1]
      }
      END { emit() }
    '
  '';

  sandboxed =
    pkgs.writeShellScriptBin "sandboxed" # sh
      ''
				set -eu

        _quiet=0
        _allow_hosts=()
				_env_fwd=()
        while [ $# -gt 0 ]; do
        	case "''${1}" in
        		-q|--quiet)
        			_quiet=1
        			shift
        			;;
        		-a|--allow)
        			if [ -z "''${2:-}" ]; then
        				printf >&2 'sandboxed: --allow requires a hostname argument\n'
        				exit 1
        			fi
        			_allow_hosts+=("''${2}")
        			shift 2
        			;;
						-e|--env)
        			if [ -z "''${2:-}" ]; then
        				printf >&2 'sandboxed: --env requires a variable name\n'
        				exit 1
        			fi
        			_env_fwd+=("''${2}")
        			shift 2
        			;;
        		*)
        			break
        			;;
        	esac
        done

        if [ $# -eq 0 ]; then
        	printf >&2 '%s\n' \
        		"Usage: sandboxed [-q] [-a <host>]... <command> [args...]" \
        		"" \
        		"Options:" \
        		"  -q, --quiet          Suppress startup messages and violation alerts" \
        		"  -a, --allow <host>   Allow connections to <host> (resolved at startup," \
        		"                       repeatable for multiple hosts)" \
						"  -e, --env <var>      Forward environment variable <var> into the" \
        		"                       sandbox (repeatable)" \
        		"" \
        		"Runs a command with all external network access blocked (localhost only" \
        		"plus any --allow hosts). Connection attempts are:" \
        		"  - Blocked at the kernel BPF layer (IPAddressDeny)" \
        		"  - Logged to auditd with a unique per-run key" \
        		"  - Printed as a visible alert to this terminal in real time" \
        		"" \
        		"Review past runs: sandboxed-log [key-prefix] [since]"
        	exit 1
        fi

        BINARY="$(basename "$1")"
        STAMP="$(date +%Y%m%d-%H%M%S)"
        AUDIT_KEY="sandbox-''${BINARY}-''${STAMP}"
        UNIT="''${AUDIT_KEY}-$$"
        CALLING_TTY="$(tty)"

				_allow_props=""
        for _host in ''${_allow_hosts[@]+"''${_allow_hosts[@]}"}; do
        	case "$_host" in
        		*/*)
        			# CIDR notation — pass through directly
        			_allow_props="''${_allow_props} --property=IPAddressAllow=''${_host}"
        			;;
        		*:*)
        			# Raw IPv6 address
        			_allow_props="''${_allow_props} --property=IPAddressAllow=''${_host}/128"
        			;;
						[0-9]*.[0-9]*.[0-9]*.[0-9]*)
        			# Raw IPv4 address
        			_allow_props="''${_allow_props} --property=IPAddressAllow=''${_host}/32"
        			;;
						*)
        			# Hostname — resolve to all A and AAAA records
        			while IFS= read -r _ip; do
        				[ -z "$_ip" ] && continue
        				case "$_ip" in
        					*:*) _allow_props="''${_allow_props} --property=IPAddressAllow=''${_ip}/128" ;;
        					*)   _allow_props="''${_allow_props} --property=IPAddressAllow=''${_ip}/32" ;;
        				esac
        			done < <({
        				getent ahosts "$_host" 2>/dev/null \
        					| ${pkgs.gawk}/bin/awk '{print $1}'
        				${pkgs.dnsutils}/bin/dig +short A "$_host" 2>/dev/null
        				${pkgs.dnsutils}/bin/dig +short AAAA "$_host" 2>/dev/null
        			} | ${pkgs.coreutils}/bin/sort -u)
        			;;
        	esac
        	if [ "$_quiet" -eq 0 ]; then
        		printf 'sandboxed: allowed %s\n' "$_host" >&2
        	fi
        done

				# Set env vars to foward
				_env_props=""
        for _var in ''${_env_fwd[@]+"''${_env_fwd[@]}"}; do
        	_val="''${!_var:-}"
        	if [ -n "$_val" ]; then
        		_env_props="''${_env_props} --property=Environment=''${_var}=''${_val}"
        	fi
        done

				# Clean stale sandbox audit rules from previous sessions whose
				# cleanup traps did not fire
				sudo ${pkgs.audit}/bin/auditctl -l 2>/dev/null \
					| ${pkgs.gnugrep}/bin/grep 'key=sandbox-' \
					| while IFS= read -r _rule; do
						sudo ${pkgs.audit}/bin/auditctl -d ''${_rule#-a } 2>/dev/null || true
					done

        sudo ${pkgs.audit}/bin/auditctl \
        	-a always,exit -F arch=b64 -S connect \
        	-F uid="$(id -u)" -F auid=4294967295 \
        	-k "''${AUDIT_KEY}"
        sudo ${pkgs.audit}/bin/auditctl \
        	-a always,exit -F arch=b32 -S connect \
        	-F uid="$(id -u)" -F auid=4294967295 \
        	-k "''${AUDIT_KEY}"

				_cleanup() {
					sudo ${pkgs.audit}/bin/auditctl \
						-d always,exit -F arch=b64 -S connect \
						-F uid="$(id -u)" -F auid=-1 \
						-F key="''${AUDIT_KEY}" 2>/dev/null || true
					sudo ${pkgs.audit}/bin/auditctl \
						-d always,exit -F arch=b32 -S connect \
						-F uid="$(id -u)" -F auid=-1 \
						-F key="''${AUDIT_KEY}" 2>/dev/null || true
					[ -n "''${_watch_pid:-}" ] && kill "''${_watch_pid}" 2>/dev/null || true
				}
        trap _cleanup EXIT INT TERM

        # Real-time watcher: process the full audit log in awk, correlating SYSCALL
        # and SOCKADDR records by their shared event seqnum. Emit at the next SYSCALL
        # boundary so the loopback filter has the destination before deciding to alert.
        # This correctly suppresses loopback EINPROGRESS (curl to localhost:8080) while
        # flagging external blocked connects where no SOCKADDR arrives (items=0).
        _watch_pid=""
        if [ "$_quiet" -eq 0 ]; then
        	sudo ${pkgs.coreutils}/bin/tail -f /var/log/audit/audit.log 2>/dev/null \
        	| ${pkgs.gawk}/bin/awk \
        			-v key="''${AUDIT_KEY}" \
        		'
        		function emit(    msg) {
        			if (evt_key != key) return
        			if (evt_exit != "-115" && evt_exit != "-111") return
        			if (evt_exe !~ /^\/nix\/store\//) return
        			if (evt_saddr != "" && evt_saddr ~ /laddr=127\.|laddr=::1|saddr_fam=local/) return

        			msg = "\r\n\033[1;31m╔══ SANDBOX VIOLATION ══════════════════════════════════════╗\033[0m\r\n" \
        						"\033[1;31m║\033[0m  key:  " key "\r\n" \
        						"\033[1;31m║\033[0m  time: " evt_time "\r\n" \
        						"\033[1;31m║\033[0m  proc: " evt_comm " (pid " evt_pid ")\r\n" \
        						"\033[1;31m║\033[0m  exe:  " evt_exe "\r\n" \
        						"\033[1;31m╚═══════════════════════════════════════════════════════════╝\033[0m\r\n"
        			printf "%s", msg
        			fflush("")
        		}

        		/type=SYSCALL/ {
        			emit()
        			evt_key=""; evt_exit=""; evt_pid=""; evt_comm=""
        			evt_exe=""; evt_saddr=""; evt_time=""; evt_id=""

        			match($0, /key="([^"]+)"/, m);    evt_key  = m[1]
        			if (evt_key != key) next

        			match($0, /msg=audit\(([^)]+)\)/, m); evt_time = m[1]
        			match(evt_time, /:([0-9]+)$/,     m); evt_id   = m[1]
        			match($0, /exit=([^ ]+)/,         m); evt_exit = m[1]
        			match($0, /pid=([^ ]+)/,           m); evt_pid  = m[1]
        			match($0, /comm="([^"]+)"/,        m); evt_comm = m[1]
        			match($0, /exe="([^"]+)"/,         m); evt_exe  = m[1]
        		}

        		/type=SOCKADDR/ {
        			if (evt_id == "") next
        			match($0, /msg=audit\([^:]+:([0-9]+)\)/, m)
        			if (m[1] != evt_id) next
        			match($0, /SADDR=\{([^}]+)\}/, m)
        			if (m[1] != "") evt_saddr = m[1]
        		}

        		END { emit() }
        	' &
        	_watch_pid=$!
        fi

        if [ "$_quiet" -eq 0 ]; then
        	printf 'sandboxed: [%s] starting %s\n' "''${AUDIT_KEY}" "''${BINARY}" >&2
        fi

        sudo ${pkgs.systemd}/bin/systemd-run \
        	--pty \
        	--same-dir \
        	--wait \
        	--collect \
        	--unit="''${UNIT}" \
        	--property="User=''${USER}" \
        	--property="IPAddressDeny=any" \
        	--property="IPAddressAllow=127.0.0.0/8" \
        	--property="IPAddressAllow=::1/128" \
        	''${_allow_props} \
        	''${_env_props} \
        	--property="Environment=HOME=''${HOME}" \
        	--property="Environment=USER=''${USER}" \
        	--property="Environment=PATH=''${PATH}" \
        	--property="Environment=XDG_CONFIG_HOME=''${XDG_CONFIG_HOME:-''${HOME}/.config}" \
        	--property="Environment=XDG_DATA_HOME=''${XDG_DATA_HOME:-''${HOME}/.local/share}" \
        	--property="Environment=XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
        	--property="Environment=DISPLAY=''${DISPLAY:-}" \
        	--property="Environment=WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-}" \
        	--property="Environment=TMUX=''${TMUX:-}" \
        	--property="Environment=TMUX_PANE=''${TMUX_PANE:-}" \
        	--property="Environment=TERM=''${TERM:-xterm-256color}" \
        	-- "$@"
      '';
in
{
  home.packages = [
    sandboxed
    sandboxLog
  ];
}
