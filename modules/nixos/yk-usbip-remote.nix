{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.yubikeyUsbipRemote;
  usbip = pkgs.linuxPackages.usbip;

  handlerScript =
    pkgs.writeShellScript "yubikey-remote-handler" # sh
      ''
        set -u

        NIX_USBIP="${usbip}/bin/usbip"

        STATE_FILE="/run/yubikey-remote/attached-port"
        LOCAL_PORT="${toString cfg.localPort}"
        VENDOR_ID="${cfg.vendorId}"
        PRODUCT_ID="${cfg.productId}"

        # Read protocol lines
        read -r _username
        read -r _command

        if [ -z "''${_username:-}" ] || [ -z "''${_command:-}" ]; then
        	printf "err: invalid request\n"
        	exit 1
        fi

        # Verify user exists and is in wheel group
        if ! id "''${_username}" > /dev/null 2>&1; then
        	printf "err: unknown user %s\n" "''${_username}"
        	exit 1
        fi

        if ! id -Gn "''${_username}" 2>/dev/null | grep -qw "wheel"; then
        	printf "err: user %s is not authorized\n" "''${_username}"
        	exit 1
        fi

        case "''${_command}" in
        	attach)
        		if [ -f "''${STATE_FILE}" ]; then
        			printf "already attached on port %s\n" "$(cat "''${STATE_FILE}")"
        			exit 0
        		fi

        		modprobe usbip_core 2>/dev/null || true
        		modprobe vhci_hcd 2>/dev/null || true

        		_busid=$(
        			"$NIX_USBIP" --tcp-port "''${LOCAL_PORT}" list -r localhost 2>&1 \
        			| grep -i "''${VENDOR_ID}:''${PRODUCT_ID}" \
        			| grep -o '[0-9][0-9]*-[0-9][0-9.]*' \
        			| head -1
        		)

        		if [ -z "''${_busid:-}" ]; then
        			printf "err: device %s:%s not found on tunnel\n" \
        				"''${VENDOR_ID}" "''${PRODUCT_ID}"
        			exit 1
        		fi

        		printf "attaching device %s (%s:%s)...\n" \
        			"''${_busid}" "''${VENDOR_ID}" "''${PRODUCT_ID}"

        		"$NIX_USBIP" --tcp-port "''${LOCAL_PORT}" attach \
        			-r localhost \
        			-b "''${_busid}" &

        		sleep 2

        		_port=$(
        			"$NIX_USBIP" port 2>&1 \
        			| grep "^Port [0-9].*Port in Use" \
        			| grep -o "[0-9][0-9]*" \
        			| head -1
        		)

        		if [ -n "''${_port:-}" ]; then
        			printf '%s\n' "''${_port}" > "''${STATE_FILE}"
        			printf "attached on port %s\n" "''${_port}"
        		else
        			printf "warning: attach may have failed, check with yk-remote status\n"
        		fi
        		;;

        	detach)
        		# Find attached port by vendor:product at detach time
        		_port=$(
        			"$NIX_USBIP" port 2>&1 \
        			| grep -B2 "''${VENDOR_ID}:''${PRODUCT_ID}" \
        			| grep "^Port [0-9]" \
        			| grep -o "[0-9][0-9]*" \
        			| head -1
        		)

        		if [ -z "''${_port:-}" ]; then
        			printf "not attached\n"
        			rm -f "''${STATE_FILE}"
        			exit 0
        		fi

        		printf "detaching port %s...\n" "''${_port}"
        		"$NIX_USBIP" detach -p "''${_port}"

        		rm -f "''${STATE_FILE}"

        		if ! "$NIX_USBIP" port 2>/dev/null | grep -q "^Port"; then
        			modprobe -r vhci_hcd 2>/dev/null || true
        			modprobe -r usbip_core 2>/dev/null || true
        		fi

        		printf "detached\n"
        		;;

        	status)
        		_port=$(
        			"$NIX_USBIP" port 2>&1 \
        			| grep -B2 "''${VENDOR_ID}:''${PRODUCT_ID}" \
        			| grep "^Port [0-9]" \
        			| grep -o "[0-9][0-9]*" \
        			| head -1
        		)

        		if [ -n "''${_port:-}" ]; then
        			printf "attached: port %s\n" "''${_port}"
        		else
        			printf "detached\n"
        		fi
        		;;

        	*)
        		printf "err: unknown command %s\n" "''${_command}"
        		exit 1
        		;;
        esac
      '';

  yk-remote =
    pkgs.writeShellScriptBin "yk-remote" # sh
      ''
        set -u

        NIX_SOCAT="${pkgs.socat}/bin/socat"

        YUBIKEY_SOCKET="/run/yubikey-remote/control"

        _usage() {
          printf "Usage: yk-remote <attach|detach|status>\n" >&2
          exit 1
        }

        if [ "$#" -eq 0 ]; then
          _usage
        fi

        _command="''${1}"

        case "''${_command}" in
          attach|detach|status) ;;
          *) _usage ;;
        esac

        if [ ! -S "''${YUBIKEY_SOCKET}" ]; then
          printf "yk-remote: yubikey-remote service not available\n" >&2
          exit 1
        fi

        # Send command and stream output directly to user
        printf '%s\n%s\n' "''${USER}" "''${_command}" \
          | "$NIX_SOCAT" - "UNIX-CONNECT:''${YUBIKEY_SOCKET}"
      '';
in
{
  options.services.yubikeyUsbipRemote = {
    enable = lib.mkEnableOption "Yubikey USBIP remote attachment service";

    localPort = lib.mkOption {
      type = lib.types.port;
      default = 3240;
      description = "Local port that the SSH tunnel forwards to";
    };

    vendorId = lib.mkOption {
      type = lib.types.strMatching "[0-9a-fA-F]{4}";
      default = "1050";
      description = "USB vendor ID of the device to attach (hex, no 0x prefix)";
    };

    productId = lib.mkOption {
      type = lib.types.strMatching "[0-9a-fA-F]{4}";
      default = "0407";
      description = "USB product ID of the device to attach (hex, no 0x prefix)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      usbip
      yk-remote
    ];

    systemd.tmpfiles.rules = [
      "d /run/yubikey-remote 0770 root wheel -"
    ];

    systemd.services.yubikey-remote = {
      description = "Yubikey USBIP remote attachment service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        Group = "wheel";
        ExecStart =
          pkgs.writeShellScript "yubikey-remote-start" # sh
            ''
              set -u

              NIX_SOCAT="${pkgs.socat}/bin/socat"
              SOCKET="/run/yubikey-remote/control"

              rm -f "''${SOCKET}"

              exec "$NIX_SOCAT" \
                UNIX-LISTEN:"''${SOCKET}",fork,mode=0660 \
                EXEC:"${handlerScript}"
            '';
        Restart = "on-failure";
        RestartSec = "5s";
        StandardError = "journal";

        AmbientCapabilities = [
          "CAP_SYS_MODULE"
          "CAP_NET_ADMIN"
          "CAP_DAC_OVERRIDE"
        ];
        CapabilityBoundingSet = [
          "CAP_SYS_MODULE"
          "CAP_NET_ADMIN"
          "CAP_DAC_OVERRIDE"
        ];

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ "/run/yubikey-remote" ];
      };
    };
  };
}
