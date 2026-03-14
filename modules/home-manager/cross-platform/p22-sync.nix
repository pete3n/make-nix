{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.p22Sync;

  syncHostType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Hostname to sync with";
      };
      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of paths relative to home directory to sync";
      };
    };
  };

  makeProfile = host: ''
    root = ${config.home.homeDirectory}
    root = ssh://${host.name}/${config.home.homeDirectory}
    ${lib.concatMapStringsSep "\n" (p: "path = ${p}") host.paths}
    ${lib.concatMapStringsSep "\n" (p: "ignore = ${p}") cfg.excludePatterns}
    servercmd = ${pkgs.unison}/bin/unison
    auto = true
    times = true
    perms = 0
  '';

  p22Sync =
    pkgs.writeShellScriptBin "p22-sync" # sh
      ''
        set -u

        NIX_UNISON="${pkgs.unison}/bin/unison"
        NIX_SSH="${pkgs.openssh}/bin/ssh"

        UNISON_DIR="${config.home.homeDirectory}/.unison"

        _host=""
        _push=0
        _pull=0
        _dry_run=0
        _path=""

        _usage() {
        	printf "Usage: p22-sync [options] <host>\n" >&2
        	printf "  --push          push local changes to remote\n" >&2
        	printf "  --pull          pull remote changes to local\n" >&2
        	printf "  --dry-run       preview changes without syncing\n" >&2
        	printf "  --path <path>   sync a single path only\n" >&2
        	printf "\nAvailable hosts:\n" >&2
        	${
           lib.concatMapStringsSep "\n" (h: ''
             		printf "  ${h.name}\n" >&2
             	'') cfg.syncHosts
         }
        	exit 1
        }

        _check_host() {
        	printf "Checking if %s is reachable...\n" "''${1}"
        	if ! "${pkgs.netcat}/bin/nc" -z -w 3 "''${1}" 22 2>/dev/null; then
        		printf "p22-sync: host %s is not reachable\n" "''${1}" >&2
        		exit 1
        	fi
        }

        _parse_args() {
        	while [ "$#" -gt 0 ]; do
        		case "''${1}" in
        			--push)
        				_push=1
        				;;
        			--pull)
        				_pull=1
        				;;
        			--dry-run)
        				_dry_run=1
        				;;
        			--path)
        				shift
        				_path="''${1:-}"
        				;;
        			--path=*)
        				_path="''${1#--path=}"
        				;;
        			--help|-h)
        				_usage
        				;;
        			-*)
        				printf "p22-sync: unknown option: %s\n" "''${1}" >&2
        				_usage
        				;;
        			*)
        				if [ -z "''${_host}" ]; then
        					_host="''${1}"
        				else
        					printf "p22-sync: unexpected argument: %s\n" "''${1}" >&2
        					_usage
        				fi
        				;;
        		esac
        		shift
        	done
        }

        _parse_args "$@"

        if [ -z "''${_host}" ]; then
        	printf "p22-sync: no host specified\n" >&2
        	_usage
        fi

        case "''${_host}" in
        	${lib.concatMapStringsSep "|" (h: h.name) cfg.syncHosts})
        		;;
        	*)
        		printf "p22-sync: unknown host: %s\n" "''${_host}" >&2
        		_usage
        		;;
        esac

        _check_host "''${_host}"

        _cmd=("$NIX_UNISON" "''${_host}")

        if [ "''${_dry_run}" = "1" ]; then
        	_cmd+=(-testserver)
        fi

        if [ "''${_push}" = "1" ]; then
        	_cmd+=(-nocreation=2 -nodeletion=2 -noupdate=2)
        elif [ "''${_pull}" = "1" ]; then
        	_cmd+=(-nocreation=1 -nodeletion=1 -noupdate=1)
        fi

        if [ -n "''${_path}" ]; then
        	_cmd+=(-path "''${_path}")
        fi

        exec "''${_cmd[@]}"
      '';
in
{
  options.programs.p22Sync = {
    enable = lib.mkEnableOption "p22 file sync using Unison";

    syncHosts = lib.mkOption {
      type = lib.types.listOf syncHostType;
      default = [ ];
      description = "List of hosts to sync with and their paths";
    };

    excludePatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Path .git"
        "Path .cache"
        "Path .local/share/Trash"
        "Path .local/share/recently-used.xbel"
        "Name *.cryptomator"
        "Name node_modules"
        "Name .DS_Store"
        "Name Thumbs.db"
      ];
      description = "Unison ignore patterns applied to all sync profiles";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.unison
      p22Sync
    ];

    home.file = lib.listToAttrs (
      map (host: {
        name = ".unison/${host.name}.prf";
        value.text = makeProfile host;
      }) cfg.syncHosts
    );
  };
}
