{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.yubikeyUsbipServer;
  usbip = pkgs.linuxPackages.usbip;

  yk-ssh =
    pkgs.writeShellScriptBin "yk-ssh" # sh
      ''
        set -u

        NIX_USBIP="${usbip}/bin/usbip"

        VENDOR_ID="${cfg.vendorId}"
        PRODUCT_ID="${cfg.productId}"
        LOCAL_PORT="${toString cfg.localPort}"
        REMOTE_PORT="${toString cfg.remotePort}"

        _destination=""
        _skip_next=0
        _ssh_exit=0

        if [ "$#" -eq 0 ]; then
        	printf "Usage: yk-ssh [ssh-options] <destination>\n" >&2
        	exit 1
        fi

        for _arg in "$@"; do
        	if [ "''${_skip_next}" = "1" ]; then
        		_skip_next=0
        		continue
        	fi
        	case "''${_arg}" in
        		-[bcDEeFIiJLlmopQRSWw])
        			_skip_next=1
        			;;
        		-*)
        			;;
        		*)
        			_destination="''${_arg}"
        			;;
        	esac
        done

        if [ -z "''${_destination}" ]; then
        	printf "yk-ssh: could not determine destination\n" >&2
        	exit 1
        fi

        CONTROL_PATH="/tmp/yk-ssh-''${USER}@''${_destination}:22"

        # Step 1: Authenticate first while Yubikey is local FIDO2 device
        printf "yk-ssh: authenticating to %s...\n" "''${_destination}"
        ssh \
        	-o ControlMaster=yes \
        	-o ControlPath="''${CONTROL_PATH}" \
        	-o ControlPersist=60 \
        	-f -N \
        	"$@"

        if [ $? -ne 0 ]; then
        	printf "yk-ssh: authentication failed\n" >&2
        	exit 1
        fi

        # Step 2: Bind Yubikey now that authentication is complete
        printf "yk-ssh: binding %s:%s for remote sharing...\n" \
        	"''${VENDOR_ID}" "''${PRODUCT_ID}"

        if ! sudo /etc/yubikey-usbip/bind; then
        	printf "yk-ssh: failed to bind device\n" >&2
        	ssh -o ControlPath="''${CONTROL_PATH}" -O exit "''${_destination}" 2>/dev/null
        	exit 1
        fi

        # Step 3: Attach yubikey on remote
        printf "yk-ssh: attaching Yubikey on remote...\n"
        ssh \
        	-o ControlMaster=no \
        	-o ControlPath="''${CONTROL_PATH}" \
        	"''${_destination}" \
        	"mkdir -p ''${HOME}/.local/state \
        	 && printf '1' > ''${HOME}/.local/state/usbip-yubikey \
        	 && yk-remote attach"

        # Step 4: Open interactive session
        printf "yk-ssh: connecting to %s with Yubikey forwarding...\n" \
        	"''${_destination}"

        ssh \
        	-o ControlMaster=no \
        	-o ControlPath="''${CONTROL_PATH}" \
        	-R "''${REMOTE_PORT}:localhost:''${LOCAL_PORT}" \
        	"$@"
        _ssh_exit=$?

        # Step 5: Detach yubikey on remote before unbinding locally
        printf "yk-ssh: detaching Yubikey on remote...\n"
        ssh \
        	-o ControlMaster=no \
        	-o ControlPath="''${CONTROL_PATH}" \
        	"''${_destination}" \
        	"yk-remote detach \
        	 && rm -f ''${HOME}/.local/state/usbip-yubikey" 2>/dev/null

        # Step 6: Unbind Yubikey and restore local drivers
        printf "yk-ssh: unbinding device...\n"
        sudo /etc/yubikey-usbip/unbind

        # Step 7: Close control master
        ssh -o ControlPath="''${CONTROL_PATH}" -O exit "''${_destination}" 2>/dev/null

        exit "''${_ssh_exit}"
      '';
in
{
  options.services.yubikeyUsbipServer = {
    enable = lib.mkEnableOption "Yubikey USBIP server for remote sharing";

    tunnelSSH = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to tunnel USBIP through SSH rather than exposing port directly";
    };

    localPort = lib.mkOption {
      type = lib.types.port;
      default = 3240;
      description = "Local port for usbipd to listen on";
    };

    remotePort = lib.mkOption {
      type = lib.types.port;
      default = 3240;
      description = "Remote port to forward to when tunneling through SSH";
    };

    vendorId = lib.mkOption {
      type = lib.types.strMatching "[0-9a-fA-F]{4}";
      default = "1050";
      description = "USB vendor ID of the device to share (hex, no 0x prefix)";
    };

    productId = lib.mkOption {
      type = lib.types.strMatching "[0-9a-fA-F]{4}";
      default = "0407";
      description = "USB product ID of the device to share (hex, no 0x prefix)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      usbip
      yk-ssh
    ];

    # Script to bind the device - called by the SSH wrapper
    environment.etc."yubikey-usbip/bind".source =
      pkgs.writeShellScript "yubikey-usbip-bind" # sh
        ''
          set -u

          NIX_USBIP="${usbip}/bin/usbip"
          NIX_USBIPD="${usbip}/bin/usbipd"

          VENDOR_ID="${cfg.vendorId}"
          PRODUCT_ID="${cfg.productId}"
          LOCAL_PORT="${toString cfg.localPort}"

          # Load required kernel modules
          modprobe usbip_core
          modprobe usbip_host

          # Find the bus ID for the device by vendor:product
          _busid=$(
            "$NIX_USBIP" list -l 2>/dev/null \
            | grep -i "''${VENDOR_ID}:''${PRODUCT_ID}" \
            | grep -oP 'busid \K[0-9]+-[0-9.]+' \
            | head -1
          )

          if [ -z "''${_busid:-}" ]; then
            printf "yubikey-usbip: device %s:%s not found\n" \
              "''${VENDOR_ID}" "''${PRODUCT_ID}" >&2
            exit 1
          fi

          printf "yubikey-usbip: binding device %s (%s:%s)\n" \
            "''${_busid}" "''${VENDOR_ID}" "''${PRODUCT_ID}"

          "$NIX_USBIP" bind -b "''${_busid}" || {
            printf "yubikey-usbip: failed to bind %s\n" "''${_busid}" >&2
            exit 1
          }

          # Start usbipd if not already running
          if ! pgrep -x usbipd > /dev/null; then
            printf "yubikey-usbip: starting usbipd on port %s\n" "''${LOCAL_PORT}"
            "$NIX_USBIPD" -D --tcp-port "''${LOCAL_PORT}" &
            sleep 1
          fi

          # Write busid to state file for unbind
          printf '%s\n' "''${_busid}" > /run/yubikey-usbip/busid
          printf "yubikey-usbip: ready\n"
        '';

    environment.etc."yubikey-usbip/unbind".source =
      pkgs.writeShellScript "yubikey-usbip-unbind" # sh
        ''
          set -u

          NIX_USBIP="${usbip}/bin/usbip"
          NIX_YKINFO="${pkgs.yubikey-personalization}/bin/ykinfo"

          if [ ! -f /run/yubikey-usbip/busid ]; then
          	printf "yubikey-usbip: no active binding found\n" >&2
          	exit 0
          fi

          _busid=$(cat /run/yubikey-usbip/busid)

          printf "yubikey-usbip: unbinding device %s\n" "''${_busid}"
          "$NIX_USBIP" unbind -b "''${_busid}" || {
          	printf "yubikey-usbip: failed to unbind %s\n" "''${_busid}" >&2
          }

          pkill -x usbipd 2>/dev/null || true

          rm -f /run/yubikey-usbip/busid

          modprobe -r usbip_host 2>/dev/null || true
          modprobe -r usbip_core 2>/dev/null || true

          sleep 1
          printf "yubikey-usbip: done\n"
        '';

    systemd.tmpfiles.rules = [
      "d /run/yubikey-usbip 0750 root wheel -"
    ];
  };
}
